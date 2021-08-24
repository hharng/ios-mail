//
//  EventsService.swift
//  ProtonMail
//
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonMail.
//
//  ProtonMail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonMail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonMail.  If not, see <https://www.gnu.org/licenses/>.

import AwaitKit
import Foundation
import Groot
import PromiseKit
import ProtonCore_Services

enum EventsFetchingStatus {
    case idle
    case started
    case running
}

protocol EventsFetching: AnyObject {
    var status: EventsFetchingStatus { get }
    func start()
    func pause()
    func resume()
    func stop()
    func call()

    func begin(subscriber: EventsConsumer)

    func fetchEvents(byLabel labelID: String, notificationMessageID : String?, completion: CompletionBlock?)
    func fetchEvents(labelID: String)
    func processEvents(counts: [[String : Any]]?)
    func processEvents(conversationCounts: [[String: Any]]?)
    func processEvents(mailSettings: [String : Any]?)
}

protocol EventsConsumer: AnyObject {
    func shouldCallFetchEvents()
}

enum EventError: Error {
    case notRunning
}

final class EventsService: Service, EventsFetching {
    private static let defaultPollingInterval: TimeInterval = 30
    private let incrementalUpdateQueue = DispatchQueue(label: "ch.protonmail.incrementalUpdateQueue", attributes: [])
    private typealias EventsObservation = (() -> Void?)?
    private(set) var status: EventsFetchingStatus = .idle
    private var subscribers: [EventsObservation] = []
    private var timer: Timer?
    private lazy var coreDataService: CoreDataService = ServiceFactory.default.get(by: CoreDataService.self)
    private lazy var lastUpdatedStore = ServiceFactory.default.get(by: LastUpdatedStore.self)
    private weak var userManager: UserManager!
    private lazy var queueManager = ServiceFactory.default.get(by: QueueManager.self)
    
    init(userManager: UserManager) {
        self.userManager = userManager
    }
    
    func start() {
        stop()
        status = .started
        resume()
        timer = Timer.scheduledTimer(withTimeInterval: Self.defaultPollingInterval, repeats: true) { [weak self] _ in
            self?.timerDidFire()
        }
    }
    
    func pause() {
        if case .idle = status {
            return
        }
        status = .started
    }
    
    func resume() {
        if case .idle = status {
            return
        }
        status = .running
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        status = .idle
        subscribers.removeAll()
    }
    
    func call() {
        if case .running = status {
            subscribers.forEach({ $0?() })
        }
    }

    private func timerDidFire() {
        call()
    }
}

extension EventsService {
    func begin(subscriber: EventsConsumer) {
        let observation = { [weak subscriber] in
            subscriber?.shouldCallFetchEvents()
        }
        subscribers.append(observation)
    }
}

// MARK: - Events Fetching
extension EventsService {
    /// fetch event logs from server. sync up the cache status to latest
    ///
    /// - Parameters:
    ///   - labelID: Label/location/folder
    ///   - notificationMessageID: the notification message
    ///   - completion: async complete handler
    func fetchEvents(byLabel labelID: String, notificationMessageID : String?, completion: CompletionBlock?) {
        guard status == .running else {
            completion?(nil, nil, EventError.notRunning as NSError)
            return
        }
        self.queueManager.queue {
            let eventAPI = EventCheckRequest(eventID: self.lastUpdatedStore.lastEventID(userID: self.userManager.userInfo.userId))
            self.userManager.apiService.exec(route: eventAPI) { (task, response: EventCheckResponse) in
                
                let eventsRes = response
                if eventsRes.refresh.contains(.contacts) {
                    _ = self.userManager.contactService.cleanUp().ensure {
                        self.userManager.contactService.fetchContacts(completion: nil)
                    }
                }

                if eventsRes.refresh.contains(.all) || eventsRes.refresh.contains(.mail) || (eventsRes.responseCode == 18001) {
                    let getLatestEventID = EventLatestIDRequest()
                    self.userManager.apiService.exec(route: getLatestEventID) { (task, eventIDResponse: EventLatestIDResponse) in
                        if let err = eventIDResponse.error {
                            completion?(task, nil, err.toNSError)
                            return
                        }
                        
                        let IDRes = eventIDResponse
                        guard !IDRes.eventID.isEmpty else {
                            completion?(task, nil, eventIDResponse.error?.toNSError)
                            return
                        }
                        
                        let completionWrapper: CompletionBlock = { task, responseDict, error in
                            if error == nil {
                                self.lastUpdatedStore.clear()
                                _ = self.lastUpdatedStore.updateEventID(by: self.userManager.userInfo.userId, eventID: IDRes.eventID).ensure {
                                    completion?(task, responseDict, error)
                                }
                                return
                            }
                            completion?(task, responseDict, error)
                        }
                        self.userManager.conversationService.cleanAll()
                        self.userManager.messageService.cleanMessage().then {
                            return self.userManager.contactService.cleanUp()
                        }.ensure {
                            switch self.userManager.getCurrentViewMode() {
                            case .conversation:
                                self.userManager.conversationService.fetchConversations(for: labelID, before: 0, unreadOnly: false, shouldReset: false) { result in
                                    switch result {
                                    case .success:
                                        completionWrapper(nil, nil, nil)
                                    case .failure(let error):
                                        completionWrapper(nil, nil, error as NSError)
                                    }
                                }
                            case .singleMessage:
                                self.userManager.messageService.fetchMessages(byLabel: labelID, time: 0, forceClean: false, isUnread: false, completion: completionWrapper)
                            }
                            self.userManager.contactService.fetchContacts(completion: nil)
                            self.userManager.messageService.labelDataService.fetchV4Labels().cauterize()
                        }.cauterize()
                    }
                } else if let messageEvents = eventsRes.messages {
                    self.processEvents(messages: messageEvents, notificationMessageID: notificationMessageID, task: task) { task, res, error in
                        if error == nil {
                            self.processEvents(conversations: eventsRes.conversations).then { (_) -> Promise<Void> in
                                return self.lastUpdatedStore.updateEventID(by: self.userManager.userInfo.userId, eventID: eventsRes.eventID)
                            }.then { (_) -> Promise<Void> in
                                if eventsRes.refresh.contains(.contacts) {
                                        return Promise()
                                    } else {
                                        return self.processEvents(contactEmails: eventsRes.contactEmails)
                                    }
                            }.then { (_) -> Promise<Void> in
                                if eventsRes.refresh.contains(.contacts) {
                                        return Promise()
                                    } else {
                                        return self.processEvents(contacts: eventsRes.contacts)
                                    }
                            }.then { (_) -> Promise<Void> in
                                self.processEvents(labels: eventsRes.labels)
                            }.then({ (_) -> Promise<Void> in
                                self.processEvents(addresses: eventsRes.addresses)
                            })
                            .ensure {
                                self.processEvents(user: eventsRes.user)
                                self.processEvents(userSettings: eventsRes.userSettings)
                                self.processEvents(mailSettings: eventsRes.mailSettings)
                                self.processEvents(counts: eventsRes.messageCounts)
                                self.processEvents(conversationCounts: eventsRes.conversationCounts)
                                self.processEvents(space: eventsRes.usedSpace)
                                
                                var outMessages : [Any] = []
                                for message in messageEvents {
                                    let msg = MessageEvent(event: message)
                                    if msg.Action == 1 {
                                        outMessages.append(msg)
                                    }
                                }
                                completion?(task, ["Messages": outMessages, "Notices": eventsRes.notices ?? [String](), "More" : eventsRes.more], nil)
                            }.cauterize()
                        }
                        else {
                            completion?(task, nil, error)
                        }
                    }
                } else {
                    if eventsRes.responseCode == 1000 {
                        self.processEvents(conversations: eventsRes.conversations).then { (_) -> Promise<Void> in
                            return self.lastUpdatedStore.updateEventID(by: self.userManager.userInfo.userId, eventID: eventsRes.eventID)
                        }.then { (_) -> Promise<Void> in
                            if eventsRes.refresh.contains(.contacts) {
                                return Promise()
                            } else {
                                return self.processEvents(contactEmails: eventsRes.contactEmails)
                            }
                        }.then { (_) -> Promise<Void> in
                            if eventsRes.refresh.contains(.contacts) {
                                return Promise()
                            } else {
                                return self.processEvents(contacts: eventsRes.contacts)
                            }
                        }.then { (_) -> Promise<Void> in
                            self.processEvents(labels: eventsRes.labels)
                        }.then({ (_) -> Promise<Void> in
                            self.processEvents(addresses: eventsRes.addresses)
                        })
                        .ensure {
                            self.processEvents(user: eventsRes.user)
                            self.processEvents(userSettings: eventsRes.userSettings)
                            self.processEvents(mailSettings: eventsRes.mailSettings)
                            self.processEvents(counts: eventsRes.messageCounts)
                            self.processEvents(conversationCounts: eventsRes.conversationCounts)
                            self.processEvents(space: eventsRes.usedSpace)
                            
                            if eventsRes.error != nil {
                                completion?(task, nil, eventsRes.error?.toNSError)
                            } else {
                                completion?(task, ["Notices": eventsRes.notices ?? [String](), "More" : eventsRes.more], nil)
                            }
                        }.cauterize()
                        return
                    }
                    if eventsRes.error != nil {
                        completion?(task, nil, eventsRes.error?.toNSError)
                    } else {
                        completion?(task, ["Notices": eventsRes.notices ?? [String](), "More" : eventsRes.more], nil)
                    }
                }
                
            }
        }
    }

    func fetchEvents(labelID: String) {
        fetchEvents(
            byLabel: labelID,
            notificationMessageID: nil,
            completion: nil
        )
    }
}

// MARK: - Events Processing
extension EventsService {
    
    /**
     this function to process the event logs
     
     :param: messages   the message event log
     :param: task       NSURL session task
     :param: completion complete call back
     */
    fileprivate func processEvents(messages: [[String : Any]], notificationMessageID: String?, task: URLSessionDataTask!, completion: CompletionBlock?) {
        struct IncrementalUpdateType {
            static let delete = 0
            static let insert = 1
            static let update_draft = 2
            static let update_flags = 3
        }
        
        // this serial dispatch queue prevents multiple messages from appearing when an incremental update is triggered while another is in progress
        self.incrementalUpdateQueue.sync {
            let context = self.coreDataService.operationContext
            self.coreDataService.enqueue(context: context) { (context) in
                var error: NSError?
                var messagesNoCache : [String] = []
                for message in messages {
                    let msg = MessageEvent(event: message)
                    switch(msg.Action) {
                    case .some(IncrementalUpdateType.delete):
                        if let messageID = msg.ID {
                            if let message = Message.messageForMessageID(messageID, inManagedObjectContext: context) {
                                let labelObjs = message.mutableSetValue(forKey: "labels")
                                labelObjs.removeAllObjects()
                                message.setValue(labelObjs, forKey: "labels")
                                context.delete(message)
                                //in case
                                error = context.saveUpstreamIfNeeded()
                                if error != nil  {
                                    Analytics.shared.error(message: .grtJSONSerialization,
                                                           error: error!,
                                                           extra: [Analytics.Reason.status: "Delete"])
                                    PMLog.D(" error: \(String(describing: error))")
                                }
                            }
                        }
                    case .some(IncrementalUpdateType.insert), .some(IncrementalUpdateType.update_draft), .some(IncrementalUpdateType.update_flags):
                        if IncrementalUpdateType.insert == msg.Action {
                            if let cachedMessage = Message.messageForMessageID(msg.ID, inManagedObjectContext: context) {
                                if !cachedMessage.contains(label: .sent) {
                                    continue
                                }
                            }
                            if let notify_msg_id = notificationMessageID {
                                if notify_msg_id == msg.ID {
                                    let _ = msg.message?.removeValue(forKey: "Unread")
                                }
                                msg.message?["messageStatus"] = 1
                                msg.message?["UserID"] = self.userManager.userInfo.userId
                            }
                            msg.message?["messageStatus"] = 1
                        }
                        
                        if let labelIDs = msg.message?["LabelIDs"] as? NSArray {
                            if labelIDs.contains("1") || labelIDs.contains("8") {
                                if let exsitMes = Message.messageForMessageID(msg.ID , inManagedObjectContext: context) {
                                    if exsitMes.messageStatus == 1 {
                                        if let subject = msg.message?["Subject"] as? String {
                                            exsitMes.title = subject
                                        }
                                        if let timeValue = msg.message?["Time"] {
                                            if let timeString = timeValue as? NSString {
                                                let time = timeString.doubleValue as TimeInterval
                                                if time != 0 {
                                                    exsitMes.time = time.asDate()
                                                }
                                            } else if let dateNumber = timeValue as? NSNumber {
                                                let time = dateNumber.doubleValue as TimeInterval
                                                if time != 0 {
                                                    exsitMes.time = time.asDate()
                                                }
                                            }
                                        }
                                        if let conversationID = msg.message?["ConversationID"] as? String {
                                            exsitMes.conversationID = conversationID
                                        }
                                        continue
                                    }
                                }
                            }
                        }
                        
                        do {
                            if let messageObject = try GRTJSONSerialization.object(withEntityName: Message.Attributes.entityName, fromJSONDictionary: msg.message ?? [String : Any](), in: context) as? Message {
                                // apply the label changes
                                if let deleted = msg.message?["LabelIDsRemoved"] as? NSArray {
                                    for delete in deleted {
                                        let labelID = delete as! String
                                        if let label = Label.labelForLabelID(labelID, inManagedObjectContext: context) {
                                            let labelObjs = messageObject.mutableSetValue(forKey: "labels")
                                            if labelObjs.count > 0 {
                                                labelObjs.remove(label)
                                                messageObject.setValue(labelObjs, forKey: "labels")
                                            }
                                        }
                                    }
                                }
                                
                                messageObject.userID = self.userManager.userInfo.userId
                                if msg.Action == IncrementalUpdateType.update_draft {
                                    messageObject.isDetailDownloaded = false
                                }

                                
                                if let added = msg.message?["LabelIDsAdded"] as? NSArray {
                                    for add in added {
                                        if let label = Label.labelForLabelID(add as! String, inManagedObjectContext: context) {
                                            let labelObjs = messageObject.mutableSetValue(forKey: "labels")
                                            labelObjs.add(label)
                                            messageObject.setValue(labelObjs, forKey: "labels")
                                        }
                                    }
                                }
                                
                                if (msg.message?["LabelIDs"] as? NSArray) != nil {
                                    messageObject.checkLabels()
                                    //TODO : add later need to know whne it is happending
                                }
                                
                                if messageObject.messageStatus == 0 {
                                    if messageObject.subject.isEmpty {
                                        messagesNoCache.append(messageObject.messageID)
                                    } else {
                                        messageObject.messageStatus = 1
                                    }
                                }

                                if messageObject.managedObjectContext == nil {
                                    if let messageid = msg.message?["ID"] as? String {
                                        messagesNoCache.append(messageid)
                                    }
                                    Analytics.shared.error(message: .grtJSONSerialization,
                                                           error: "GRTJSONSerialization Insert - context nil")
                                }
                            } else {
                                // when GRTJSONSerialization inset returns no thing
                                if let messageid = msg.message?["ID"] as? String {
                                    messagesNoCache.append(messageid)
                                }
                                PMLog.D(" case .Some(IncrementalUpdateType.insert), .Some(IncrementalUpdateType.update1), .Some(IncrementalUpdateType.update2): insert empty")
                                Analytics.shared.error(message: .grtJSONSerialization,
                                                       error: "GRTJSONSerialization Insert - insert empty")
                            }
                        } catch let err as NSError {
                            // when GRTJSONSerialization insert failed
                            if let messageid = msg.message?["ID"] as? String {
                                messagesNoCache.append(messageid)
                            }
                            var status = ""
                            switch msg.Action {
                            case IncrementalUpdateType.update_draft:
                                status = "Update1"
                            case IncrementalUpdateType.update_flags:
                                status = "Update2"
                            case IncrementalUpdateType.insert:
                                status = "Insert"
                            case IncrementalUpdateType.delete:
                                status = "Delete"
                            default:
                                status = "Other: \(String(describing: msg.Action))"
                                break
                            }
                            Analytics.shared.error(message: .grtJSONSerialization,
                                                   error: err,
                                                   extra: [Analytics.Reason.status: status])
                            PMLog.D(" error: \(err)")
                        }
                    default:
                        PMLog.D(" unknown type in message: \(message)")
                        
                    }
                    //TODO:: move this to the loop and to catch the error also put it in noCache queue.
                    error = context.saveUpstreamIfNeeded()
                    if error != nil  {
                        Analytics.shared.error(message: .grtJSONSerialization,
                                               error: error!,
                                               extra: [Analytics.Reason.status: "Save"])
                        PMLog.D(" error: \(String(describing: error))")
                    }
                }

                self.userManager.messageService.fetchMessageInBatches(messageIDs: messagesNoCache)

                DispatchQueue.main.async {
                    completion?(task, nil, error)
                    return
                }
            }
        }
    }
    
    fileprivate func processEvents(conversations: [[String: Any]]?) -> Promise<Void> {
        struct IncrementalUpdateType {
            static let delete = 0
            static let insert = 1
            static let update_draft = 2
            static let update_flags = 3
        }
        
        guard let conversationsDict = conversations else {
            return Promise()
        }
//        PMLog.D(conversationsDict.debugDescription)
        return Promise { seal in
            self.incrementalUpdateQueue.sync {
                let context = self.coreDataService.operationContext
                self.coreDataService.enqueue(context: context) { (context) in
                    defer {
                        seal.fulfill_()
                    }
                    var conversationsNeedRefetch: [String] = []
                    
                    var error: NSError?
                    for conDict in conversationsDict {
                        //Parsing conversation event
                        guard let conversationEvent = ConversationEvent(event: conDict) else {
                            continue
                        }
                        switch conversationEvent.action {
                        case IncrementalUpdateType.delete:
                            if let conversation = Conversation.conversationForConversationID(conversationEvent.ID, inManagedObjectContext: context) {
                                let labelObjs = conversation.mutableSetValue(forKey: Conversation.Attributes.labels)
                                labelObjs.removeAllObjects()
                                context.delete(conversation)
                                
                                error = context.saveUpstreamIfNeeded()
                                if error != nil {
                                    Analytics.shared.error(message: .coreDataError,
                                                           error: error!,
                                                           extra: [Analytics.Reason.status: "Delete"])
                                    PMLog.D(" error: \(String(describing: error))")
                                }
                            }
                        case IncrementalUpdateType.insert: // treat it as same as update
                            if Conversation.conversationForConversationID(conversationEvent.ID, inManagedObjectContext: context) != nil {
                                continue
                            }
                            do {
                                if let conversationObject = try GRTJSONSerialization.object(withEntityName: Conversation.Attributes.entityName, fromJSONDictionary: conversationEvent.conversation, in: context) as? Conversation {
                                    conversationObject.userID = self.userManager.userInfo.userId
                                    if let labels = conversationObject.labels as? Set<ContextLabel> {
                                        for label in labels {
                                            label.order = conversationObject.order
                                        }
                                    }
                                }
                                error = context.saveUpstreamIfNeeded()
                                if error != nil {
                                    Analytics.shared.error(message: .coreDataError,
                                                           error: error!,
                                                           extra: [Analytics.Reason.status: "Insert"])
                                    PMLog.D(" error: \(String(describing: error))")
                                    conversationsNeedRefetch.append(conversationEvent.ID)
                                }
                            } catch {
                                //Refetch after insert failed
                                conversationsNeedRefetch.append(conversationEvent.ID)
                                Analytics.shared.error(message: .grtJSONSerialization,
                                                       error: error,
                                                       extra: [Analytics.Reason.status: "Insert"])
                            }
                        case IncrementalUpdateType.update_draft, IncrementalUpdateType.update_flags:
                            do {
                                var conversationData = conversationEvent.conversation
                                conversationData["ID"] = conDict["ID"] as? String
                                
                                if var labels = conversationData["Labels"] as? [[String: Any]] {
                                    for (index, _) in labels.enumerated() {
                                        labels[index]["UserID"] = self.userManager.userInfo.userId
                                        labels[index]["ConversationID"] = conversationData["ID"]
                                    }
                                    conversationData["Labels"] = labels
                                }
                                
                                if let conversationObject = try GRTJSONSerialization.object(withEntityName: Conversation.Attributes.entityName, fromJSONDictionary: conversationData, in: context) as? Conversation {
                                    if let labels = conversationObject.labels as? Set<ContextLabel> {
                                        for label in labels {
                                            label.order = conversationObject.order
                                        }
                                    }
                                    if let messageCount = conversationEvent.conversation["NumMessages"] as? NSNumber, conversationObject.numMessages != messageCount {
                                        conversationsNeedRefetch.append(conversationEvent.ID)
                                    }
                                }
                                error = context.saveUpstreamIfNeeded()
                                if error != nil {
                                    Analytics.shared.error(message: .coreDataError,
                                                           error: error!,
                                                           extra: [Analytics.Reason.status: "Update"])
                                    PMLog.D(" error: \(String(describing: error))")
                                    conversationsNeedRefetch.append(conversationEvent.ID)
                                }
                            } catch {
                                conversationsNeedRefetch.append(conversationEvent.ID)
                                Analytics.shared.error(message: .grtJSONSerialization,
                                                       error: error,
                                                       extra: [Analytics.Reason.status: "Update"])
                            }
                        default:
                            break
                        }
                        
                        error = context.saveUpstreamIfNeeded()
                        if error != nil  {
                            Analytics.shared.error(message: .grtJSONSerialization,
                                                   error: error!,
                                                   extra: [Analytics.Reason.status: "Save"])
                            PMLog.D(" error: \(String(describing: error))")
                        }
                    }
                    
                    self.userManager.conversationService.fetchConversations(with: conversationsNeedRefetch, completion: nil)
                }
            }
        }
    }
    
    /// Process contacts from event logs
    ///
    /// - Parameter contacts: contact events
    fileprivate func processEvents(contacts: [[String : Any]]?) -> Promise<Void> {
        guard let contacts = contacts else {
            return Promise()
        }
        
        return Promise { seal in
            let context = self.coreDataService.operationContext
            self.coreDataService.enqueue(context: context) { (context) in
                defer {
                    seal.fulfill_()
                }
                for contact in contacts {
                    let contactObj = ContactEvent(event: contact)
                    switch(contactObj.action) {
                    case .delete:
                        if let contactID = contactObj.ID {
                            if let tempContact = Contact.contactForContactID(contactID, inManagedObjectContext: context) {
                                context.delete(tempContact)
                            }
                        }
                        //save it earily
                        if let error = context.saveUpstreamIfNeeded()  {
                            PMLog.D(" error: \(error)")
                        }
                    case .insert, .update:
                        do {
                            if let outContacts = try GRTJSONSerialization.objects(withEntityName: Contact.Attributes.entityName,
                                                                                  fromJSONArray: contactObj.contacts,
                                                                                  in: context) as? [Contact] {
                                for c in outContacts {
                                    c.isDownloaded = false
                                    c.userID = self.userManager.userInfo.userId
                                    if let emails = c.emails.allObjects as? [Email] {
                                        emails.forEach { (e) in
                                            e.userID = self.userManager.userInfo.userId
                                        }
                                    }
                                }
                            }
                        } catch let ex as NSError {
                            PMLog.D(" error: \(ex)")
                        }
                        if let error = context.saveUpstreamIfNeeded() {
                            PMLog.D(" error: \(error)")
                        }
                    default:
                        PMLog.D(" unknown type in contact: \(contact)")
                    }
                }
            }
        }
    }
    
    /// Process contact emails this is like metadata update
    ///
    /// - Parameter contactEmails: contact email events
    fileprivate func processEvents(contactEmails: [[String : Any]]?) -> Promise<Void> {
        guard let emails = contactEmails else {
            return Promise()
        }
        
        return Promise { seal in
            let context = self.coreDataService.operationContext
            self.coreDataService.enqueue(context: context) { (context) in
                defer {
                    seal.fulfill_()
                }
                for email in emails {
                    let emailObj = EmailEvent(event: email)
                    switch(emailObj.action) {
                    case .delete:
                        if let emailID = emailObj.ID {
                            if let tempEmail = Email.EmailForID(emailID, inManagedObjectContext: context) {
                                context.delete(tempEmail)
                            }
                        }
                    case .insert, .update:
                        do {
                            if let outContacts = try GRTJSONSerialization.objects(withEntityName: Contact.Attributes.entityName,
                                                                                  fromJSONArray: emailObj.contacts,
                                                                                  in: context) as? [Contact] {
                                for c in outContacts {
                                    c.isDownloaded = false
                                    c.userID = self.userManager.userInfo.userId
                                    if let emails = c.emails.allObjects as? [Email] {
                                        emails.forEach { (e) in
                                            e.userID = self.userManager.userInfo.userId
                                        }
                                    }
                                }
                            }
                            
                        } catch let ex as NSError {
                            PMLog.D(" error: \(ex)")
                        }
                    default:
                        PMLog.D(" unknown type in contact: \(email)")
                    }
                }
                
                if let error = context.saveUpstreamIfNeeded()  {
                    PMLog.D(" error: \(error)")
                }
            }
        }
    }
    
    /// Process Labels include Folders and Labels.
    ///
    /// - Parameter labels: labels events
    fileprivate func processEvents(labels: [[String : Any]]?) -> Promise<Void> {
        struct IncrementalUpdateType {
            static let delete = 0
            static let insert = 1
            static let update = 2
        }
        
        
        if let labels = labels {
            return Promise { seal in
                // this serial dispatch queue prevents multiple messages from appearing when an incremental update is triggered while another is in progress
                self.incrementalUpdateQueue.sync {
                    let context = self.coreDataService.operationContext
                    self.coreDataService.enqueue(context: context) { (context) in
                        defer {
                            seal.fulfill_()
                        }
                        for labelEvent in labels {
                            let label = LabelEvent(event: labelEvent)
                            switch(label.Action) {
                            case .some(IncrementalUpdateType.delete):
                                if let labelID = label.ID {
                                    if let dLabel = Label.labelForLabelID(labelID, inManagedObjectContext: context) {
                                        context.delete(dLabel)
                                    }
                                }
                            case .some(IncrementalUpdateType.insert), .some(IncrementalUpdateType.update):
                                do {
                                    if var new_or_update_label = label.label {
                                        new_or_update_label["UserID"] = self.userManager.userInfo.userId
                                        try GRTJSONSerialization.object(withEntityName: Label.Attributes.entityName, fromJSONDictionary: new_or_update_label, in: context)
                                    }
                                } catch let ex as NSError {
                                    PMLog.D(" error: \(ex)")
                                }
                            default:
                                PMLog.D(" unknown type in message: \(label)")
                            }
                        }
                        if let error = context.saveUpstreamIfNeeded(){
                            PMLog.D(" error: \(error)")
                        }
                    }
                }
            }
        } else {
            return Promise()
        }
    }
    
    /// Process User information
    ///
    /// - Parameter userInfo: User dict
    fileprivate func processEvents(user: [String : Any]?) {
        guard let userEvent = user else {
            return
        }
        self.userManager?.updateFromEvents(userInfoRes: userEvent)
    }
    fileprivate func processEvents(userSettings: [String : Any]?) {
        guard let userSettingEvent = userSettings else {
            return
        }
        self.userManager?.updateFromEvents(userSettingsRes: userSettingEvent)
    }
    func processEvents(mailSettings: [String : Any]?) {
        guard let mailSettingEvent = mailSettings else {
            return
        }
        self.userManager?.updateFromEvents(mailSettingsRes: mailSettingEvent)
    }
    
    fileprivate func processEvents(addresses: [[String : Any]]?) -> Promise<Void> {
        guard let addrEvents = addresses else {
            return Promise()
        }
        return Promise { seal in
            self.incrementalUpdateQueue.async {
                for addrEvent in addrEvents {
                    let address = AddressEvent(event: addrEvent)
                    switch(address.action) {
                    case .delete:
                        if let addrID = address.ID {
                            self.userManager?.deleteFromEvents(addressIDRes: addrID)
                        }
                    case .insert, .update1:
                        guard let addrID = address.ID, let addrDict = address.address else {
                            break
                        }
                        let addrRes = AddressesResponse()
                        _ = addrRes.parseAddr(res: addrDict)

                        guard addrRes.addresses.count == 1, let parsedAddr = addrRes.addresses.first, parsedAddr.addressID == addrID else {
                            break
                        }
                        self.userManager?.setFromEvents(addressRes: parsedAddr)
                        guard let user = self.userManager else {
                            break
                        }
                        do {
                            try `await`(user.userService.activeUserKeys(userInfo: user.userinfo, auth: user.authCredential))
                        } catch let error {
                            print(error.localizedDescription)
                        }
                    default:
                        PMLog.D(" unknown type in message: \(address)")
                    }
                }
                seal.fulfill_()
            }
        }
    }
    
    /// Process Message count from event logs
    ///
    /// - Parameter counts: message count dict
    func processEvents(counts: [[String : Any]]?) {
        guard let messageCounts = counts, messageCounts.count > 0 else {
            return
        }
        
        lastUpdatedStore.resetUnreadCounts()
        self.coreDataService.enqueue(context: self.coreDataService.operationContext) { (context) in
            for count in messageCounts {
                if let labelID = count["LabelID"] as? String {
                    guard let unread = count["Unread"] as? Int else {
                        continue
                    }
                    self.lastUpdatedStore.updateUnreadCount(by: labelID, userID: self.userManager.userInfo.userId, count: unread, type: .singleMessage, shouldSave: false)
                }
            }
            
            if let error = context.saveUpstreamIfNeeded() {
                PMLog.D(error.localizedDescription)
            }
            
            let unreadCount: Int = self.lastUpdatedStore.unreadCount(by: Message.Location.inbox.rawValue, userID: self.userManager.userInfo.userId, type: .singleMessage)
            
            guard let viewMode = self.userManager?.getCurrentViewMode() else {
                return
            }
            if viewMode == .singleMessage {
                var badgeNumber = unreadCount
                if  badgeNumber < 0 {
                    badgeNumber = 0
                }
                UIApplication.setBadge(badge: badgeNumber)
            }
        }
    }
    
    func processEvents(conversationCounts: [[String: Any]]?) {
        guard let conversationCounts = conversationCounts, conversationCounts.count > 0 else {
            return
        }
        
        self.coreDataService.enqueue(context: self.coreDataService.operationContext) { (context) in
            for count in conversationCounts {
                if let labelID = count["LabelID"] as? String {
                    guard let unread = count["Unread"] as? Int else {
                        continue
                    }
                    self.lastUpdatedStore.updateUnreadCount(by: labelID, userID: self.userManager.userInfo.userId, count: unread, type: .conversation, shouldSave: false)
                }
            }
            
            if let error = context.saveUpstreamIfNeeded() {
                PMLog.D(error.localizedDescription)
            }
            
            let unreadCount: Int = self.lastUpdatedStore.unreadCount(by: Message.Location.inbox.rawValue, userID: self.userManager.userInfo.userId, type: .conversation)
            
            guard let viewMode = self.userManager?.getCurrentViewMode() else {
                return
            }
            if viewMode == .conversation {
                var badgeNumber = unreadCount
                if  badgeNumber < 0 {
                    badgeNumber = 0
                }
                UIApplication.setBadge(badge: badgeNumber)
            }
        }
    }
    
    
    fileprivate func processEvents(space usedSpace : Int64?) {
        guard let usedSpace = usedSpace else {
            return
        }
        self.userManager?.update(usedSpace: usedSpace)
    }
}
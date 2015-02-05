//
//  Message.swift
//  ProtonMail
//
//  Created by Eric Chamberlain on 1/30/15.
//  Copyright (c) 2015 ArcTouch. All rights reserved.
//

import Foundation
import CoreData

class Message: NSManagedObject {
    struct Attributes {
        static let messageID = "messageID"
    }

    @NSManaged var expirationTime: NSDate?
    @NSManaged var hasAttachment: Bool
    @NSManaged var isEncrypted: Bool
    @NSManaged var isForwarded: Bool
    @NSManaged var isRead: Bool
    @NSManaged var isReplied: Bool
    @NSManaged var isRepliedAll: Bool
    @NSManaged var isStarred: Bool
    @NSManaged var locationNumber: NSNumber
    @NSManaged var messageID: String
    @NSManaged var recipientList: String
    @NSManaged var recipientNameList: String
    @NSManaged var sender: String
    @NSManaged var senderName: String
    @NSManaged var tag: String
    @NSManaged var time: NSDate?
    @NSManaged var title: String
    @NSManaged var totalSize: NSNumber
    
    @NSManaged var attachments: NSSet
    @NSManaged var detail: MessageDetail
    
    // MARK: - Private variables
    
    private let starredTag = "starred"
    
    // MARK: - Public methods

    convenience init(context: NSManagedObjectContext) {
        self.init(entity: NSEntityDescription.entityForName(Message.entityName(), inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
    }
    
    class func entityName() -> String {
        return "Message"
    }
    
    class func fetchOrCreateMessageForMessageID(messageID: String, context: NSManagedObjectContext) -> (message: Message?, error: NSError?) {
        var error: NSError?
        var message: Message?
        let fetchRequest = NSFetchRequest(entityName: entityName())
        fetchRequest.predicate = NSPredicate(format: "%K == %@", Attributes.messageID, messageID)
        
        if let messages = context.executeFetchRequest(fetchRequest, error: &error) {
            switch(messages.count) {
            case 0:
                message = Message(context: context)
            case 1:
                message = messages.first as? Message
            default:
                message = messages.first as? Message
                NSLog("\(__FUNCTION__) messageID: \(messageID) has \(messages.count) messages.")
            }
            
            message?.messageID = messageID
        }
        
        return (message, error)
    }
    
    func setIsStarred(isStarred: Bool, completion: (NSError? -> Void)) {
        sharedMessageDataService.setMessage(self, isStarred: isStarred, completion: completion)
    }
    
    func updateTag(tag: String) {
        self.tag = tag
        isStarred = tag.rangeOfString(starredTag) != nil
    }
}

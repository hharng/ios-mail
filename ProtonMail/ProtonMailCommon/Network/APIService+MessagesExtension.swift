//
//  APIService+MessagesExtension.swift
//  ProtonMail
//
//
// Copyright 2015 ArcTouch, Inc.
// All rights reserved.
//
// This file, its contents, concepts, methods, behavior, and operation
// (collectively the "Software") are protected by trade secret, patent,
// and copyright laws. The use of the Software is governed by a license
// agreement. Disclosure of the Software to third parties, in any form,
// in whole or in part, is expressly prohibited except as authorized by
// the license agreement.
//

import Foundation

//TODO :: all the request post put ... all could abstract a body layer, after change the request only need the url and request object.
/// Messages extension
extension APIService {
    
    fileprivate struct MessagePath {
        static let base = AppConstants.API_PATH + "/messages"
    }
   
    enum Filter: Int {
        case noFilter = -2
        case read = 0
        case unRead = 1
    }
    
    enum Order: Int {
        case ascending = 0
        case descending = 1
    }
            
    enum SortedColumn: String {
        case date = "Date"
        case from = "From"
        case size = "Size"
        case subject = "Subject"
    }
    
    struct MessageErrorCode {
        static let credentialExpired = 10
        static let credentialInvalid = 20
        static let invalidGrant = 30
        static let unableToParseToken = 40
    }
    
    //new way to do the new work calls
    func POST<T> ( _ apiRequest : ApiRequest<T>!, completion: CompletionBlock?) {
        let parameterStrings = apiRequest.toDictionary()
        request(method: .post,
                path: apiRequest.path(),
                parameters: parameterStrings,
                headers: ["x-pm-apiversion": apiRequest.apiVersion()],
                completion: completion)
    }
    
    func PUT<T> ( _ apiRequest : ApiRequest<T>!, completion: CompletionBlock?) {
        let parameterStrings = apiRequest.toDictionary()
        request(method: .put,
                path: apiRequest.path(),
                parameters: parameterStrings,
                headers: ["x-pm-apiversion":
                    apiRequest.apiVersion()],
                completion: completion)
    }

    func GET<T> ( _ apiRequest : ApiRequest<T>!, completion: CompletionBlock?) {
        let parameterStrings = apiRequest.toDictionary()
        request(method: .get,
                path: apiRequest.path(),
                parameters: parameterStrings,
                headers: ["x-pm-apiversion": apiRequest.apiVersion()],
                completion: completion)
    }
    
    func Delete<T> ( _ apiRequest : ApiRequest<T>!, completion: CompletionBlock?) {
        let parameterStrings = apiRequest.toDictionary()
        request(method: .delete,
                path: apiRequest.path(),
                parameters: parameterStrings,
                headers: ["x-pm-apiversion": apiRequest.apiVersion()],
                completion: completion)
    }
    
    // MARK : Need change soon tempry for no outside incoming emails
    func fetchLatestMessageList(_ time: Int, completion: @escaping CompletionBlock) {
        let path = MessagePath.base + "/latest/\(time)"
        request(method: .get,
                path: path,
                parameters: nil,
                headers: ["x-pm-apiversion": 3],
                completion: completion)
    }
    
    
    // MARK: - Public methods
    func messageCheck(timestamp: TimeInterval, completion: CompletionBlock?) {
        let path = "/messages/check"
        let parameters = ["t" : timestamp]
        request(method: .get,
                path: path,
                parameters: parameters,
                headers: ["x-pm-apiversion": 3],
                completion: completion)
    }
    
    func messageCountForLocation(_ location: Int, completion: CompletionBlock?) {
        let path = "/messages"
        let parameters = ["Location" : location]
        let completionWrapper = completionWrapperParseCompletion(completion, forKey: "MessageCount")
        request(method: .get,
                path: path,
                parameters: parameters,
                headers: ["x-pm-apiversion": 3],
                completion: completionWrapper)
    }
    
    func messageCreate(
        _ messageID: String = "0",
        recipientList: String = "",
        bccList: String = "",
        ccList: String = "",
        title: String = "",
        passwordHint: String = "",
        expirationDate: Date? = nil,
        isEncrypted: NSNumber,
        body: [String : String],
        attachments: [Attachment],
        completion: CompletionBlock?) {
            let path = "/messages"
            let parameterStrings: [String : String] = [
                "MessageID" : messageID,
                "RecipientList" : recipientList,
                "BCCList" : bccList,
                "CCList" : ccList,
                "MessageTitle" : title,
                "PasswordHint" : passwordHint]
            
            var parameters: [String : Any] = filteredMessageStringParameters(parameterStrings)
            
            if expirationDate != nil {
                parameters["ExpirationTime"] = Double(expirationDate?.timeIntervalSince1970 ?? 0)
            }
            parameters["IsEncrypted"] = isEncrypted.isEncrypted() ? 1 : 0
            parameters["MessageBody"] = body
        
        request(method: .post,
                path: path,
                parameters: parameters,
                headers: ["x-pm-apiversion": 3],
                completion: completion)
    }
    
    func messageDraft(
        _ recipientList: String = "",
        bccList: String = "",
        ccList: String = "",
        title: String = "",
        passwordHint: String = "",
        expirationDate: Date? = nil,
        isEncrypted: NSNumber,
        body: [String : String],
        attachments: [Attachment]?,
        completion: CompletionBlock?) {
            let path = "/messages/draft"
            let parameters: [String : Any] = [
                "RecipientList" : recipientList,
                "BCCList" : bccList,
                "CCList" : ccList,
                "MessageTitle" : title,
                "PasswordHint" : passwordHint,
                "ExpirationTime" : (expirationDate?.timeIntervalSince1970 ?? 0),
                "IsEncrypted" : isEncrypted,
                "MessageBody" : body]
        
            request(method: .post,
                    path: path,
                    parameters: parameters,
                    headers: ["x-pm-apiversion": 3],
                    completion: completion)
    }
    
    func messageDraftUpdate(
        messageID: String,
        recipientList: String = "",
        bccList: String = "",
        ccList: String = "",
        title: String = "",
        passwordHint: String = "",
        expirationDate: Date? = nil,
        isEncrypted: NSNumber,
        body: [String : String],
        attachments: [Attachment]?,
        completion: CompletionBlock?) {
        
            let path = "/messages/\(messageID)/draft"
            let parameters: [String : Any] = [
                "MessageID" : messageID,
                "RecipientList" : recipientList,
                "BCCList" : bccList,
                "CCList" : ccList,
                "MessageTitle" : title,
                "PasswordHint" : passwordHint,
                "ExpirationTime" : (expirationDate?.timeIntervalSince1970 ?? 0),
                "IsEncrypted" : isEncrypted,
                "MessageBody" : body]
        
            request(method: .post,
                    path: path,
                    parameters: parameters,
                    headers: ["x-pm-apiversion": 3],
                    completion: completion)
    }
    
    
    func messageDetail(messageID: String, completion: @escaping CompletionBlock) {
        let path = MessagePath.base + "/\(messageID)"
        PMLog.D("path: \(path)")
        request(method: .get,
                path: path,
                parameters: nil,
                headers: ["x-pm-apiversion": 3],
                completion: completion)
    }
    
    func messageSearch(_ query: String, page: Int, completion: CompletionBlock?) {
        let path = MessagePath.base
        let parameters :  [String : Any] = [
            "Keyword" : query,
            "Page" : page
        ]
        
        request(method: .get,
                path: path,
                parameters: parameters,
                headers: ["x-pm-apiversion": 3],
                completion: completion)
    }
    
    
    // MARK: - Private methods
    fileprivate func filteredMessageStringParameters(_ parameters: [String : String]) -> [String : String] {
        var filteredParameters: [String : String] = [:]
        for (key, value) in parameters {
            if !value.isEmpty {
                filteredParameters[key] = value
            }
        }
        return filteredParameters
    }
}
//
//  Message.swift
//  ProtonMail
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
import CoreData

public class Message: NSManagedObject {

    @NSManaged var bccList: String
    @NSManaged var bccNameList: String
    @NSManaged var body: String
    @NSManaged var ccList: String
    @NSManaged var ccNameList: String
    @NSManaged var expirationTime: NSDate?
    @NSManaged var hasAttachments: Bool
    @NSManaged var header: String
    @NSManaged var isDetailDownloaded: Bool
    @NSManaged var isEncrypted: NSNumber
    @NSManaged var isForwarded: Bool
    @NSManaged var isRead: Bool
    @NSManaged var isReplied: Bool
    @NSManaged var isRepliedAll: Bool
    @NSManaged var isStarred: Bool
    @NSManaged var lastModified: NSDate?
    @NSManaged var locationNumber: NSNumber
    @NSManaged var messageID: String
    @NSManaged var passwordEncryptedBody: String
    @NSManaged var password: String
    @NSManaged var passwordHint: String
    @NSManaged var recipientList: String
    @NSManaged var recipientNameList: String
    @NSManaged var sender: String
    @NSManaged var senderName: String
    @NSManaged var spamScore: NSNumber
    @NSManaged var tag: String
    @NSManaged var time: NSDate?
    @NSManaged var title: String
    @NSManaged var totalSize: NSNumber
    @NSManaged var latestUpdateType : NSNumber
    @NSManaged var needsUpdate : Bool
    @NSManaged var orginalMessageID: String?
    @NSManaged var orginalTime: NSDate?
    @NSManaged var action: NSNumber?
    @NSManaged var isSoftDelete: Bool
    @NSManaged var expirationOffset : Int32
    
    @NSManaged var addressID : String?
    
    @NSManaged var messageType : NSNumber  // 0 message 1 rate
    @NSManaged var messageStatus : NSNumber  // bit 0x00000000 no metadata  0x00000001 has
    
    @NSManaged var isShowedImages : Bool
    
    @NSManaged var attachments: NSSet
    @NSManaged var labels: NSSet
}


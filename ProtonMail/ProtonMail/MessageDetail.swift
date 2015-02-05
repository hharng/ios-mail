//
//  ProtonMail.swift
//  ProtonMail
//
//  Created by Eric Chamberlain on 2/4/15.
//  Copyright (c) 2015 ArcTouch. All rights reserved.
//

import Foundation
import CoreData

class MessageDetail: NSManagedObject {

    @NSManaged var bccList: String
    @NSManaged var bccNameList: String
    @NSManaged var body: String
    @NSManaged var ccList: String
    @NSManaged var ccNameList: String
    @NSManaged var header: String
    @NSManaged var spamScore: NSNumber
    @NSManaged var message: Message
    @NSManaged var attachments: NSSet

    var hasAttachments: Bool {
        return attachments.isEmpty
    }
}

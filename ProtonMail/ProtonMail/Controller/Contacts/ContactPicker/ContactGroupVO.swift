//
//  ContactGroupVO.swift
//  ProtonMail
//
//  Created by Chun-Hung Tseng on 2018/9/26.
//  Copyright © 2018 ProtonMail. All rights reserved.
//

import Foundation

class ContactGroupVO: NSObject, ContactPickerModelProtocol
{
    var modelType: ContactPickerModelState {
        get {
            return .contactGroup
        }
    }
    
    var ID: String
    var contactTitle: String
    var displayName: String?
    var displayEmail: String?
    var contactSubtitle: String?
    var contactImage: UIImage?
    var lock: UIImage?
    var hasPGPPined: Bool
    var hasNonePM: Bool
    
    func notes(type: Int) -> String {
        return ""
    }
    
    func setType(type: Int) { }
    
    func lockCheck(progress: () -> Void, complete: LockCheckComplete?) {}
    
    // contact group sub-selection
    var selectedMembers: Set<String> // [address]
    
    func getSelectedEmailsWithDetail() -> [(Group: String, Name: String, Address: String)]
    {
        var result: [(Group: String, Name: String, Address: String)] = []
        
        if let context = sharedCoreDataService.mainManagedObjectContext {
            for member in selectedMembers {
                if let email = Email.EmailForAddressWithContact(member,
                                                                contactID: ID,
                                                                inManagedObjectContext: context) {
                    result.append((self.contactTitle, email.name, member))
                } else {
                    // TODO: handle error
                    PMLog.D("Can't find the data for address = \(member)")
                }
            }
        }
        
        return result
    }
    
    func getSelectedEmails() -> [String] {
        return self.selectedMembers.map{$0}
    }
    
    func setSelectedEmails(selectedMembers: [String])
    {
        self.selectedMembers = Set<String>()
        for member in selectedMembers {
            self.selectedMembers.insert(member)
        }
    }
    
    func selectAllEmail() {
        if let context = sharedCoreDataService.mainManagedObjectContext {
            if let label = Label.labelForLabelName(contactTitle,
                                                   inManagedObjectContext: context) {
                for email in label.emails.allObjects as! [Email] {
                    self.selectedMembers.insert(email.email)
                }
            }
        }
    }
    
    func getContactGroupInfo() -> (total: Int, color: String) {
        if let context = sharedCoreDataService.mainManagedObjectContext {
            if let label = Label.labelForLabelName(contactTitle,
                                                   inManagedObjectContext: context) {
                return (label.emails.count, label.color)
            }
        }
        
        return (0, ColorManager.defaultColor)
    }
    
    /**
     Calculates the group size, selected member count, and group color
     Information for composer collection view cell
    */
    func getGroupInformation() -> (memberSelected: Int, totalMemberCount: Int, groupColor: String) {
        let errorResponse = (0, 0, ColorManager.defaultColor)
        
        var emailAddresses = Set<String>()
        var color = ""
        if let context = sharedCoreDataService.mainManagedObjectContext {
            // (1) get all email in the contact group
            if let label = Label.labelForLabelName(self.contactTitle,
                                                   inManagedObjectContext: context),
                let emails = label.emails.allObjects as? [Email] {
                color = label.color
                
                for email in emails {
                    emailAddresses.insert(email.email)
                }
            } else {
                // TODO: handle error
                return errorResponse
            }
            
            // (2) get all that is NOT in the contact group, but is selected
            for address in self.selectedMembers {
                if emailAddresses.contains(address) == false {
                    if let emailObj = Email.EmailForAddressWithContact(address,
                                                                    contactID: ID,
                                                                    inManagedObjectContext: context) {
                        emailAddresses.insert(emailObj.email)
                    } else {
                        // TODO: handle error
                        PMLog.D("Can't find \(address) in core data")
                    }
                }
            }
            
            return (selectedMembers.count, emailAddresses.count, color)
        } else {
            return errorResponse
        }
    }
    
    init(ID: String, name: String) {
        self.ID = ID
        self.contactTitle = name
        self.displayName = nil
        self.displayEmail = nil
        self.contactSubtitle = ""
        self.contactImage = nil
        self.lock = nil
        self.hasPGPPined = false
        self.hasNonePM = false
        self.selectedMembers = Set<String>()
    }
}

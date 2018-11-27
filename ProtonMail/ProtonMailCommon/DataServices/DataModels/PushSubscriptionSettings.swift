//
//  PushSubscriptionSettings.swift
//  ProtonMail
//
//  Created by Anatoly Rosencrantz on 08/11/2018.
//  Copyright © 2018 ProtonMail. All rights reserved.
//

import Foundation

struct PushSubscriptionSettings: Hashable, Codable {
    typealias EncryptionKit = PushNotificationDecryptor.EncryptionKit
    
    let token, UID: String
    var encryptionKit: EncryptionKit!
    
    static func == (lhs: PushSubscriptionSettings, rhs: PushSubscriptionSettings) -> Bool {
        return lhs.token == rhs.token && lhs.UID == rhs.UID
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.token)
        hasher.combine(self.UID)
    }
    
    init(token: String, UID: String) {
        self.token = token
        self.UID = UID
    }
    
    #if !APP_EXTENSION
    mutating func generateEncryptionKit() throws {
        let crypto = PMNOpenPgp.createInstance()!
        let keypair = try crypto.generateRandomKeypair()
        self.encryptionKit = EncryptionKit(passphrase: keypair.passphrase, privateKey: keypair.privateKey, publicKey: keypair.publicKey)
    }
    #endif
}
//
//  String+Toast+Extension.swift
//  ProtonMail
//
//  Created by Yanfeng Zhang on 7/31/17.
//  Copyright © 2017 ProtonMail. All rights reserved.
//

import Foundation

extension String {
    
    public func alertToast() -> Void {
        let window : UIWindow = UIApplication.shared.windows.last as UIWindow!
        let hud : MBProgressHUD = MBProgressHUD.showAdded(to: window, animated: true)
        hud.mode = MBProgressHUDMode.text
        hud.labelText = NSLocalizedString("Alert", comment: "alert title");
        hud.detailsLabelText = self
        hud.removeFromSuperViewOnHide = true
        hud.hide(true, afterDelay: 3)
    }
    
}
//
//  MenuViewController.swift
//  ProtonMail
//
//
//  Copyright (c) 2019 Proton Technologies AG
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


import UIKit
import ProtonCore_AccountSwitcher

final class MenuViewController: UIViewController, AccessibleView {

    @IBOutlet private var menuWidth: NSLayoutConstraint!
    @IBOutlet private var shortNameView: UIView!
    @IBOutlet private var primaryUserview: UIView!
    @IBOutlet private var avatarLabel: UILabel!
    @IBOutlet private var displayName: UILabel!
    @IBOutlet private var arrowBtn: UIButton!
    @IBOutlet private var addressLabel: UILabel!
    @IBOutlet private var tableView: UITableView!
    
    private(set) var viewModel: MenuVMProtocol!
    private(set) var coordinator: MenuCoordinator!
    
    func set(vm: MenuVMProtocol, coordinator: MenuCoordinator) {
        self.viewModel = vm
        self.coordinator = coordinator
    }

    override var prefersStatusBarHidden: Bool {
        true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        assert(self.viewModel != nil, "viewModel can't be empty")
        assert(self.coordinator != nil, "viewModel can't be empty")
        
        self.viewModel.userDataInit()
        self.viewInit()
        
        generateAccessibilityIdentifiers()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.appDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.viewModel.menuViewInit()

        self.view.accessibilityElementsHidden = false
        self.view.becomeFirstResponder()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if UIAccessibility.isVoiceOverRunning {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0),
                                  at: .top, animated: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.sideMenuController?.contentViewController.view.isUserInteractionEnabled = true
    }
}

// MARK: Private functions
extension MenuViewController {
    private func viewInit() {
        self.menuWidth.constant = self.viewModel.menuWidth
        self.tableView.backgroundColor = .clear
        self.tableView.register(MenuItemTableViewCell.self)
        self.tableView.tableFooterView = self.createTableFooter()
        self.primaryUserview.setCornerRadius(radius: 6)
        self.shortNameView.setCornerRadius(radius: 2)
        self.avatarLabel.adjustsFontSizeToFitWidth = true
        self.avatarLabel.accessibilityElementsHidden =  true
        self.addGesture()
    }
    
    private func addGesture() {
        let ges = UILongPressGestureRecognizer(target: self, action: #selector(longPressOnPrimaryUserView(ges:)))
        ges.minimumPressDuration = 0
        self.primaryUserview.addGestureRecognizer(ges)
    }
    
    @objc func longPressOnPrimaryUserView(ges: UILongPressGestureRecognizer) {
        
        let point = ges.location(in: self.primaryUserview)
        let origin = self.primaryUserview.bounds
        let isInside = origin.contains(point)
        
        let state = ges.state
        switch state {
        case .began:
            self.setPrimaryUserview(hightlight: true)
        case.changed:
            if !isInside {
                self.setPrimaryUserview(hightlight: false)
            }
        case .ended:
            self.setPrimaryUserview(hightlight: false)
            if isInside {
                self.showAccountSwitcher()
            }
        default:
            break
        }
    }
    
    private func closeMenu() {
        self.sideMenuController?.hideMenu()
    }
    
    private func showSignupAlarm(_ sender: UIView?) {
        let shouldDeleteMessageInQueue = self.viewModel.isCurrentUserHasQueuedMessage()
        var message = LocalString._signout_confirmation
        
        if shouldDeleteMessageInQueue {
            message = LocalString._signout_confirmation_having_pending_message
        } else {
            if let user = self.viewModel.currentUser {
                if let nextUser = self.viewModel.secondUser {
                    message = String(format: LocalString._signout_confirmation, nextUser.defaultEmail)
                } else {
                    message = String(format: LocalString._signout_confirmation_one_account, user.defaultEmail)
                }
            }
        }
        
        let alertController = UIAlertController(title: LocalString._signout_title, message: message, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: LocalString._sign_out, style: .destructive, handler: { (action) -> Void in
            if shouldDeleteMessageInQueue {
                self.viewModel.removeAllQueuedMessageOfCurrentUser()
            }
            self.viewModel.signOut(userID: self.viewModel.currentUser?.userinfo.userId ?? "").cauterize()
        }))
        alertController.popoverPresentationController?.sourceView = sender ?? self.view
        alertController.popoverPresentationController?.sourceRect = (sender == nil ? self.view.frame : sender!.bounds)
        alertController.addAction(UIAlertAction(title: LocalString._general_cancel_button, style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func showAccountSwitcher() {
        let list = self.viewModel.getAccountList()
        var origin = self.primaryUserview.frame.origin
        origin.y += self.view.safeAreaInsets.top
        let switcher = try! AccountSwitcher(accounts: list, origin: origin)
        let userIDs = list.map {$0.userID}
        for id in userIDs {
            _ = self.viewModel.getUnread(of: id).done { (unread) in
                switcher.updateUnread(userID: id, unread: unread)
            }
        }
        guard let sideMenu = self.sideMenuController else {return}
        switcher.present(on: sideMenu, delegate: self)
    }

    private func setPrimaryUserview(hightlight: Bool) {
        let color = hightlight ? UIColor(RRGGBB: UInt(0x494D55)): UIColor(RRGGBB: UInt(0x303239))
        self.primaryUserview.backgroundColor = color
        self.arrowBtn.isHighlighted = hightlight
    }
    
    private func showTempMsg(msg: String) {
        msg.alertToast()
    }

    @objc
    func appDidEnterBackground() {
        if let sideMenu = self.sideMenuController {
            AccountSwitcher.dismiss(from: sideMenu)
        }
    }
}

// MARK: MenuUIProtocol
extension MenuViewController: MenuUIProtocol {
    func update(email: String) {
        self.addressLabel.text = email
    }
    
    func update(displayName: String) {
        self.displayName.text = displayName
    }
    
    func update(avatar: String) {
        self.avatarLabel.text = avatar
    }
    
    func updateMenu(section: Int?) {
        guard let _section = section else {
            self.tableView.reloadData()
            return
        }
        
        self.tableView.beginUpdates()
        self.tableView.reloadSections(IndexSet(integer: _section),
                                      with: .fade)
        self.tableView.endUpdates()
        
    }
    
    func reloadRow(indexPath: IndexPath) {
        self.tableView.beginUpdates()
        self.tableView.reloadRows(at: [indexPath], with: .fade)
        self.tableView.endUpdates()
    }
    
    func insertRows(indexPaths: [IndexPath]) {
        self.tableView.beginUpdates()
        self.tableView.insertRows(at: indexPaths, with: .fade)
        self.tableView.endUpdates()
    }
    
    func deleteRows(indexPaths: [IndexPath]) {
        self.tableView.beginUpdates()
        self.tableView.deleteRows(at: indexPaths, with: .fade)
        self.tableView.endUpdates()
    }
    
    func update(rows: [IndexPath], insertRows: [IndexPath], deleteRows: [IndexPath]) {
        
        self.tableView.beginUpdates()
        for indexPath in rows {
            guard let cell = self.tableView.cellForRow(at: indexPath) as? MenuItemTableViewCell,
                  let label = self.viewModel.getMenuItem(indexPath: indexPath) else {
                continue
            }
            cell.config(by: label, useFillIcon: self.viewModel.enableFolderColor, delegate: self)
            cell.update(iconColor: self.viewModel.getColor(of: label))
        }
        
        self.tableView.insertRows(at: insertRows, with: .fade)
        self.tableView.deleteRows(at: deleteRows, with: .fade)
        self.tableView.endUpdates()
    }
    
    func navigateTo(label: MenuLabel) {
        if let sideMenu = self.sideMenuController {
            AccountSwitcher.dismiss(from: sideMenu)
        }
        self.coordinator.go(to: label)
    }
    
    func showToast(message: String) {
        message.alertToastBottom()
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addOKAction()
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: TableViewDelegate
extension MenuViewController: UITableViewDelegate, UITableViewDataSource, MenuItemTableViewCellDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.viewModel.sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.viewModel.numberOfRowsIn(section: section)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 48
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "\(MenuItemTableViewCell.self)", for: indexPath) as! MenuItemTableViewCell
        guard let label = self.viewModel.getMenuItem(indexPath: indexPath) else {
            // todo error handle
            fatalError("Shouldn't be nil")
        }
        cell.config(by: label, useFillIcon: self.viewModel.enableFolderColor, delegate: self)
        cell.update(iconColor: self.viewModel.getColor(of: label))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let label = self.viewModel.getMenuItem(indexPath: indexPath) else {
            // todo error handle
            fatalError("Shouldn't be nil")
        }
        switch label.location {
        case .lockapp:
            keymaker.lockTheApp() // remove mainKey from memory
            let _ = sharedServices.get(by: UnlockManager.self).isUnlocked() // provoke mainKey obtaining
            self.closeMenu()
        case .signout:
            let cell = tableView.cellForRow(at: indexPath)
            self.showSignupAlarm(cell)
        case .customize(_):
            self.coordinator.go(to: label)
        case .addLabel:
            guard self.viewModel.allowToCreate(type: .label) else {
                let title = LocalString._creating_label_not_allowed
                let message = LocalString._upgrade_to_create_label
                self.showAlert(title: title, message: message)
                return
            }
            self.coordinator.go(to: label)
        case .addFolder:
            guard self.viewModel.allowToCreate(type: .folder) else {
                let title = LocalString._creating_folder_not_allowed
                let message = LocalString._upgrade_to_create_folder
                self.showAlert(title: title, message: message)
                return
            }
            self.coordinator.go(to: label)
        default:
            self.coordinator.go(to: label)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 56
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let _section = self.viewModel.sections[section]
        let view = self.createHeaderView(section: _section)
        return view
    }
    
    func clickCollapsedArrow(labelID: String) {
        self.viewModel.clickCollapsedArrow(labelID: labelID)
    }
    
    private func createHeaderView(section: MenuSection) -> UIView {
        let vi = UIView()
        vi.backgroundColor = .clear
        
        if section == .inboxes { return vi }
        
        let label = UILabel(font: .systemFont(ofSize: 13), text: section.title, textColor: UIColor(RRGGBB: UInt(0x9ca0aa)))
        label.translatesAutoresizingMaskIntoConstraints = false
        
        vi.addSubview(label)
        
        label.leadingAnchor.constraint(equalTo: vi.leadingAnchor, constant: 16).isActive = true
        label.bottomAnchor.constraint(equalTo: vi.bottomAnchor, constant: -8).isActive = true
        return vi
    }
    
    private func createTableFooter() -> UIView {
        let version = self.viewModel.appVersion()
        let label = UILabel(font: .systemFont(ofSize: 13), text: "ProtonMail \(version)", textColor: UIColor(RRGGBB: UInt(0x727680)))
        label.frame = CGRect(x: 0, y: 0, width: self.menuWidth.constant, height: 80)
        label.textAlignment = .center
        return label
    }
}

extension MenuViewController: AccountSwitchDelegate {
    func switchTo(userID: String) {
        self.viewModel.activateUser(id: userID)
    }

    func signinAccount(for mail: String, userID: String?) {
        if let id = userID {
            self.viewModel.prepareLogin(userID: id)
        } else {
            self.viewModel.prepareLogin(mail: mail)
        }
    }

    func signoutAccount(userID: String, viewModel: AccountManagerVMDataSource) {
        _ = self.viewModel.signOut(userID: userID).done { [weak self] _ in
            guard let _self = self else {return}
            let list = _self.viewModel.getAccountList()
            viewModel.updateAccountList(list: list)
        }
    }

    func removeAccount(userID: String, viewModel: AccountManagerVMDataSource) {
        _ = self.viewModel.signOut(userID: userID).done { [weak self] _ in
            guard let _self = self else {return}
            _self.viewModel.removeDisconnectAccount(userID: userID)
            let list = _self.viewModel.getAccountList()
            viewModel.updateAccountList(list: list)
        }
    }
    
    func accountManagerWillAppear() {
        guard let sideMenu = self.sideMenuController else {return}
        sideMenu.hideMenu()
    }
}


extension MenuViewController: Deeplinkable {
    var deeplinkNode: DeepLink.Node {
        return DeepLink.Node(name: String(describing: MenuViewController.self))
    }
}

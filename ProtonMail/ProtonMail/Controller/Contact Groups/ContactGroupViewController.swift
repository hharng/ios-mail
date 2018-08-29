//
//  ContactGroupViewController.swift
//  ProtonMail
//
//  Created by Chun-Hung Tseng on 2018/8/17.
//  Copyright © 2018 ProtonMail. All rights reserved.
//

import UIKit
import CoreData

/*
 This is a temporary view. This should be integrate into the contact VC.
 
 Prototyping goals:
 1. Present all contact groups here
 2. Tap on the cell to view detail
 */

class ContactGroupsViewController: ProtonMailViewController, ViewModelProtocol
{
    var viewModel: ContactGroupsViewModel!
    let kToContactGroupDetailSegue: String = "toContactGroupDetailSegue"
    var fetchedContactGroupResultsController: NSFetchedResultsController<NSFetchRequestResult>? = nil
    var refreshControl: UIRefreshControl!
    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func cancelButton(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func setViewModel(_ vm: Any) {
        viewModel = vm as! ContactGroupsViewModel
    }
    
    func inactiveViewModel() {
    }
    
    override func viewDidLoad() {
        self.navigationItem.title = "Contact Groups"
        
        tableView.noSeparatorsBelowFooter()
        
        // TODO: how to update remotely?
        fetchedContactGroupResultsController = sharedLabelsDataService.fetchedResultsController(.contactGroup)
        fetchedContactGroupResultsController?.delegate = self
        if let fetchController = fetchedContactGroupResultsController {
            do {
                try fetchController.performFetch()
            } catch let error as NSError {
                PMLog.D("fetchedContactGroupResultsController Error: \(error.userInfo)")
            }
        }
        
        // refresh control
        refreshControl = UIRefreshControl()
        refreshControl.backgroundColor = UIColor(RRGGBB: UInt(0xDADEE8))
        refreshControl.addTarget(self,
                                 action: #selector(fireFetch),
                                 for: UIControlEvents.valueChanged)
        tableView.addSubview(self.refreshControl)
        refreshControl.tintColor = UIColor.gray
        refreshControl.tintColorDidChange()
    }
    
    @objc func fireFetch() {
        self.viewModel.fetchAllContactGroup()
        
        // TODO: use completion handler for ending this refreshing action
        self.refreshControl.endRefreshing()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kToContactGroupDetailSegue {
            let contactGroupEditViewController = segue.destination.childViewControllers[0] as! ContactGroupEditViewController
            let contactGroup = sender as! Label
            
            let refreshHandler = {
                () -> Void in
                return
            }
            
            sharedVMService.contactGroupEditViewModel(contactGroupEditViewController,
                                                      state: .edit,
                                                      contactGroupID: contactGroup.labelID,
                                                      name: contactGroup.name,
                                                      color: contactGroup.color,
                                                      refreshHandler: refreshHandler)
        }
    }
}

extension ContactGroupsViewController: UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let fetchedController = fetchedContactGroupResultsController {
            return fetchedController.fetchedObjects?.count ?? 0
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "ContactGroupCell", for: indexPath)
        
        if let fetchedController = fetchedContactGroupResultsController {
            if let label = fetchedController.object(at: indexPath) as? Label {
                cell.textLabel?.text = label.name
            } else {
                // TODO; better error handling
                cell.textLabel?.text = "Error in retrieving contact group name in core data"
            }
        }
        
        return cell
    }
}

extension ContactGroupsViewController: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let fetchedController = fetchedContactGroupResultsController {
            self.performSegue(withIdentifier: kToContactGroupDetailSegue,
                              sender: fetchedController.object(at: indexPath))
        }
    }
}

extension ContactGroupsViewController: NSFetchedResultsControllerDelegate
{
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        print("Here!!!")
        switch type {
        case .insert:
            print("Insert")
            if let newIndexPath = newIndexPath {
                PMLog.D("Section: \(newIndexPath.section) Row: \(newIndexPath.row) ")
                tableView.insertRows(at: [newIndexPath], with: UITableViewRowAnimation.fade)
            }
        case .delete:
            print("Delete")
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.fade)
            }
        case .update:
            print("Update")
            let cell = tableView.cellForRow(at: indexPath!) as! UITableViewCell
            if let fetchedController = fetchedContactGroupResultsController {
                if let label = fetchedController.object(at: indexPath!) as? Label {
                    cell.textLabel?.text = label.name
                } else {
                    // TODO: better error handling
                    cell.textLabel?.text = "Error in retrieving contact group name in core data"
                }
            }
        case .move:
//            tableView.deleteRows(at: [indexPath!], with: .automatic)
//            tableView.insertRows(at: [newIndexPath!], with: .automatic)
            return
        }
    }
}

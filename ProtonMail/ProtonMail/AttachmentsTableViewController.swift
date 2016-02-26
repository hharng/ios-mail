//
//  AttachmentsTableViewController.swift
//
//
//  Created by Yanfeng Zhang on 10/16/15.
//
//

import UIKit
import AssetsLibrary


protocol AttachmentsTableViewControllerDelegate {
    
    func attachments(attViewController: AttachmentsTableViewController, didFinishPickingAttachments: [AnyObject]) -> Void
    
    func attachments(attViewController: AttachmentsTableViewController, didPickedAttachment: Attachment) -> Void
    
    func attachments(attViewController: AttachmentsTableViewController, didDeletedAttachment: Attachment) -> Void
}


class AttachmentsTableViewController: UITableViewController {
    
    var attachments: [AnyObject] = [] {
        didSet {
            tableView?.reloadData()
        }
    }
    
    var message: Message!
    
    var delegate: AttachmentsTableViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.registerNib(UINib(nibName: "AttachmentTableViewCell", bundle: nil), forCellReuseIdentifier: AttachmentTableViewCell.Constant.identifier)
        self.tableView.separatorStyle = .None
        
        if let navigationController = navigationController {
            configureNavigationBar(navigationController)
            setNeedsStatusBarAppearanceUpdate()
        }
        
        self.clearsSelectionOnViewWillAppear = false
    }
    
    func configureNavigationBar(navigationController: UINavigationController) {
        navigationController.navigationBar.barStyle = UIBarStyle.Black
        navigationController.navigationBar.barTintColor = UIColor.ProtonMail.Nav_Bar_Background;
        navigationController.navigationBar.translucent = false
        navigationController.navigationBar.tintColor = UIColor.whiteColor()
        
        let navigationBarTitleFont = UIFont.robotoLight(size: UIFont.Size.h2)
        navigationController.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: UIColor.whiteColor(),
            NSFontAttributeName: navigationBarTitleFont
        ]
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func doneAction(sender: AnyObject) {
        self.delegate?.attachments(self, didFinishPickingAttachments: attachments)
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func addAction(sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Photo Library"), style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            let picker: UIImagePickerController = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
            self.presentViewController(picker, animated: true, completion: nil)
        }))
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Take a Photo"), style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera)) {
                let picker: UIImagePickerController = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = UIImagePickerControllerSourceType.Camera
                self.presentViewController(picker, animated: true, completion: nil)
            }
        }))
        alertController.popoverPresentationController?.barButtonItem = sender
        alertController.popoverPresentationController?.sourceRect = self.view.frame
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel"), style: UIAlertActionStyle.Cancel, handler: nil))
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    
    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return attachments.count;
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(AttachmentTableViewCell.Constant.identifier, forIndexPath: indexPath) as! AttachmentTableViewCell
        
        if attachments.count > indexPath.row {
            if let att = attachments[indexPath.row] as? Attachment {
                PMLog.D("\(att)")
                PMLog.D("\(att.fileName)")
                cell.configCell(att.fileName ?? "unknow file", fileSize:  Int(att.fileSize ?? 0), showDownload: false)
                
                let crossView = UILabel();
                crossView.text = "Remove"
                crossView.sizeToFit()
                crossView.textColor = UIColor.whiteColor()
                cell.defaultColor = UIColor.lightGrayColor()
                cell.setSwipeGestureWithView(crossView, color: UIColor.ProtonMail.MessageActionTintColor, mode: MCSwipeTableViewCellMode.Exit, state: MCSwipeTableViewCellState.State3  ) { (cell, state, mode) -> Void in
                    if let indexp = self.tableView.indexPathForCell(cell) {
                        if let att = self.attachments[indexPath.row] as? Attachment {
                            if att.attachmentID != "0" {
                                self.delegate?.attachments(self, didDeletedAttachment: att)
                                self.attachments.removeAtIndex(indexPath.row)
                                self.tableView.reloadData()
                            } else {
                                cell.swipeToOriginWithCompletion(nil)
                            }
                        } else {
                            cell.swipeToOriginWithCompletion(nil)
                        }
                    } else {
                        self.tableView.reloadData()
                    }
                }
            }
        }
        cell.selectionStyle = .None;
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 44;
    }
    
    
    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return NO if you do not want the specified item to be editable.
    return true
    }
    */
    
    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
    // Delete the row from the data source
    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    } else if editingStyle == .Insert {
    // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
    }
    */
    
    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
    
    }
    */
    
    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return NO if you do not want the item to be re-orderable.
    return true
    }
    */
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    }
    */
    
    
    
    
    
    // MARK: - UIImagePickerControllerDelegate
    
    
}

extension AttachmentsTableViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        
        let tempImage = info[UIImagePickerControllerOriginalImage] as? UIImage
        let type = info[UIImagePickerControllerMediaType] as? String
        let url = info[UIImagePickerControllerReferenceURL] as? NSURL
        let img_jpg = UIImage(data:UIImageJPEGRepresentation(tempImage, 1.0))!
        
        let library = ALAssetsLibrary()
        library.assetForURL(url, resultBlock:
            { (asset: ALAsset!) -> Void in
                if asset != nil {
                    var fileName = asset.defaultRepresentation().filename()
                    let mimeType = asset.defaultRepresentation().UTI()
                    let attachment = img_jpg.toAttachment(self.message, fileName: fileName, type: mimeType)
                    self.attachments.append(attachment!)
                    self.delegate?.attachments(self, didPickedAttachment: attachment!)
                    picker.dismissViewControllerAnimated(true, completion: nil)
                    self.tableView.reloadData()
                } else {
                    var fileName = "\(NSUUID().UUIDString).jpg"
                    let mimeType = "image/jpg"
                    let attachment = img_jpg.toAttachment(self.message, fileName: fileName, type: mimeType)
                    self.attachments.append(attachment!)
                    self.delegate?.attachments(self, didPickedAttachment: attachment!)
                    picker.dismissViewControllerAnimated(true, completion: nil)
                    self.tableView.reloadData()
                }
            })  { (error:NSError!) -> Void in
                var fileName = "\(NSUUID().UUIDString).jpg"
                let mimeType = "image/jpg"
                let attachment = img_jpg.toAttachment(self.message, fileName: fileName, type: mimeType)
                self.delegate?.attachments(self, didPickedAttachment: attachment!)
                self.attachments.append(attachment!)
                picker.dismissViewControllerAnimated(true, completion: nil)
                self.tableView.reloadData()
        }
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        UIApplication.sharedApplication().setStatusBarStyle(UIStatusBarStyle.LightContent, animated: false)
        configureNavigationBar(navigationController)
    }
}

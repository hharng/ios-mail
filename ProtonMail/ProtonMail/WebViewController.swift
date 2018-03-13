//
//  WebViewController.swift
//  ProtonMail
//
//  Created by Yanfeng Zhang on 3/12/18.
//  Copyright © 2018 ProtonMail. All rights reserved.
//

import UIKit

class WebViewController: UIViewController, ViewModelProtocolNew {
    typealias argType = WebViewModel
    func setViewModel(_ vm: WebViewModel) {
         self.viewModel = vm
    }
    
    func inactiveViewModel() {
        //ignored
    }
    
    @IBOutlet weak var webView: UIWebView!
    private var viewModel : WebViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let url = self.viewModel.url
        
        let request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60.0)
        webView.loadRequest(request)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
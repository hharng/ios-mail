//
//  CountryPickerViewController.swift
//  ProtonMail
//
//  Created by Yanfeng Zhang on 3/29/16.
//  Copyright (c) 2016 ProtonMail. All rights reserved.
//

import Foundation


protocol CountryPickerViewControllerDelegate {
    func dismissed();
    func apply(_ country : CountryCode);
}

class CountryPickerViewController : UIViewController {
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var applyButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!

    var delegate : CountryPickerViewControllerDelegate?
    
    fileprivate var countryCodes : [CountryCode] = []
    fileprivate var titleIndex : [String] = [String]()
    fileprivate var indexCache : [String: Int] = [String: Int]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.layer.cornerRadius = 4;
        
        tableView.sectionIndexColor = UIColor(hexColorCode: "#9199CB")
        
        self.prepareSource();
    }
    
    func prepareSource () {
        var country_code : String = ""
        let bundleInstance = Bundle(for: type(of: self))
        if let localFile = bundleInstance.path(forResource: "phone_country_code", ofType: "geojson") {
            if let content = try? String(contentsOfFile:localFile, encoding:String.Encoding.utf8) {
                country_code = content
            }
        }
        
        let parsedObject: Any? = try! JSONSerialization.jsonObject(with: country_code.data(using: String.Encoding.utf8, allowLossyConversion: false)!, options: JSONSerialization.ReadingOptions.allowFragments) as Any?
        if let objects = parsedObject as? [Dictionary<String,Any>] {
            countryCodes = CountryCode.getCountryCodes(objects)
        }
        countryCodes.sort(by: { (v1, v2) -> Bool in
            return v1.country_en < v2.country_en
        })
        
        var lastLetter : String = ""
        for (index, value) in countryCodes.enumerated() {
            let firstIndex = value.country_en.characters.index(value.country_en.startIndex, offsetBy: 1)
            let firstString = value.country_en.substring(to: firstIndex)
            if firstString != lastLetter {
                lastLetter = firstString
                titleIndex.append(lastLetter)
                indexCache[lastLetter] = index
            }
        }
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    @IBAction func applyAction(_ sender: AnyObject) {
        if let indexPath = self.tableView.indexPathForSelectedRow {
            if indexPath.row < countryCodes.count {
                let country = countryCodes[indexPath.row]
                delegate?.apply(country)
            }
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancelAction(_ sender: AnyObject) {
        delegate?.dismissed()
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
}

// MARK: - UITableViewDataSource

extension CountryPickerViewController: UITableViewDataSource {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if (self.tableView.responds(to: #selector(setter: UITableViewCell.separatorInset))) {
            self.tableView.separatorInset = UIEdgeInsets.zero
        }
        
        if (self.tableView.responds(to: #selector(setter: UIView.layoutMargins))) {
            self.tableView.layoutMargins = UIEdgeInsets.zero
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let countryCell = tableView.dequeueReusableCell(withIdentifier: "country_code_table_cell", for: indexPath) as! CountryCodeTableViewCell
        if indexPath.row < countryCodes.count {
            let country = countryCodes[indexPath.row]
            countryCell.ConfigCell(country, vc: self)
        }
        return countryCell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return countryCodes.count
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (cell.responds(to: #selector(setter: UITableViewCell.separatorInset))) {
            cell.separatorInset = UIEdgeInsets.zero
        }
        
        if (cell.responds(to: #selector(setter: UIView.layoutMargins))) {
            cell.layoutMargins = UIEdgeInsets.zero
        }
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if let selectIndex = indexCache[title] {
            tableView.scrollToRow(at: IndexPath(row: selectIndex, section: 0), at: UITableViewScrollPosition.top, animated: true)
        }
        return -1
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return titleIndex;
    }
    
    
}

// MARK: - UITableViewDelegate

extension CountryPickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 45.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // verify whether the user is checking messages or not
    }
}






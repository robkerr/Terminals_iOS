//
//  CitySearchVC.swift
//  Terminals
//
//  Created by Robert Kerr on 5/1/16.
//  Copyright © 2016 MobileToolworks. All rights reserved.
//

import UIKit
import Alamofire
import Mixpanel

class CitySearchVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    
    var searchActive : Bool = false
    var _cityMasterList : [String]?
    var _cityMatchedList : [String] = []
    var _searchText = ""
    var _selectedItem = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        getCities()
    }
    
    override func  preferredStatusBarStyle()-> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }

    
    override func viewDidAppear(animated: Bool) {
        self.searchBar.becomeFirstResponder()
        
        let mixpanel = Mixpanel.sharedInstance()
        mixpanel.track("Search Appeared")

    }

    func getCities() {
        
        let url = "https://demo.mobiletoolworks.com/terminals/cities"

        let mixpanel = Mixpanel.sharedInstance()
        mixpanel.timeEvent("getCities")
        
        Alamofire.request(.GET, url).responseJSON { response in
            
            mixpanel.track("getCitites")
                
            if let statusCode = response.response?.statusCode {
                
                if statusCode != 200 {
                    var errorMessage = "Unknown error occurred"
                    
                    if let dict = response.result.value as? [String:AnyObject], msg = dict["Message"] as? String {
                        errorMessage = "Error \(statusCode): \(msg)"
                    }
                    
                    print(errorMessage)
                    
                } else {
                    self._cityMasterList = (response.result.value as? [String])!
                }
            }
        }
        
    }

    func searchAutocompleteEntriesWithSubstring(subString: String)
    {
        _cityMatchedList.removeAll()
        
        if let masterList = _cityMasterList {
            for curString in masterList
            {
                if curString.containsString(subString) {
                    _cityMatchedList.append(curString)
                }
            }
        }

        print("Found \(_cityMatchedList.count) items.")
        
        //tableView.reloadData()
    }

    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        searchActive = true;
    }
    
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        
        _cityMatchedList = _cityMasterList!.filter({ (text) -> Bool in
            let tmp: NSString = text
            let range = tmp.rangeOfString(searchText, options: NSStringCompareOptions.CaseInsensitiveSearch)
            return range.location != NSNotFound
        })
        if(_cityMatchedList.count == 0){
            searchActive = false;
        } else {
            searchActive = true;
        }
        self.tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let cityMaster = _cityMasterList {
            if searchActive {
                return _cityMatchedList.count
            } else {
                return cityMaster.count
            }
        }
        
        return 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell")! as UITableViewCell;

        if let cityMaster = _cityMasterList {
            if(searchActive){
                cell.textLabel?.text = _cityMatchedList[indexPath.row]
            } else {
                cell.textLabel?.text = cityMaster[indexPath.row];
            }
        }
        
        return cell;
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        _selectedItem = ""

        if let cityMaster = _cityMasterList {
            if searchActive {
                _selectedItem = _cityMatchedList[indexPath.row]
            } else {
                _selectedItem = cityMaster[indexPath.row]
            }
        }

        // Set the new search city and change to the map tab
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.searchCity = _selectedItem
        self.tabBarController?.selectedIndex = 0
    }
    
    
}


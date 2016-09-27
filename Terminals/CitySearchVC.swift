//**************************************************************************************
//
//    Filename: CitySearchVC.swift
//     Project: Terminals
//
//      Author: Robert Kerr 
//   Copyright: Copyright © 2016 MobileToolworks. All rights reserved.
//
//  Maintenance History
//          5/1/16      File Created
//          9/26/16     Converted to use CoreData instead of MongoDB/AWS
//
//**************************************************************************************

import UIKit
import CoreData

class CitySearchVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    var resultsController : NSFetchedResultsController<Terminal>!
    var context : NSManagedObjectContext!
    
    var searchActive : Bool = false
    var _cityMatchedList : [SelectedCity] = []
    var _searchText = ""
    var _selectedItem : SelectedCity?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            self.context = appDelegate.coreDataStack.viewContext
        } else {
            fatalError()
        }
        
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        
    }
    
    override var  preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    
    override func viewDidAppear(_ animated: Bool) {
        getCities()
        self.searchBar.becomeFirstResponder()
    }

    //**************************************************************************************
    //
    //      Function: getCities
    //   Description: Fetch a sorted list of cities from CoreData
    //
    //**************************************************************************************
    func getCities() {
        print(#function)
        
        let request : NSFetchRequest<Terminal> = Terminal.fetchRequest()
        let descriptor = NSSortDescriptor(key: #keyPath(Terminal.city), ascending: true)
        request.sortDescriptors = [descriptor]
        resultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        do {
           // resultsController.delegate = self
            try resultsController.performFetch()
            print("###########  FETCHED \(resultsController.fetchedObjects?.count) ROWS ###################")
            tableView.reloadData()
        } catch {
            print("Error performing fetch \(error.localizedDescription)")
        }
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchActive = true;
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    
    //**************************************************************************************
    //
    //      Function: searchBar - textDidChange
    //   Description: User is typing in the search bar, so let's find matches
    //
    //**************************************************************************************
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        _cityMatchedList.removeAll()
        
        if searchText == "" {
            searchActive = false
        } else {
            searchActive = true
            
            if let objects = resultsController.fetchedObjects {
                
                // If query result is empty, query it
                if objects.count == 0 {
                    getCities()
                }
                
                for obj in objects {
                    if let name = obj.name {
                        if let city = obj.city {
                            if name.uppercased().contains(searchText.uppercased()) || city.uppercased().contains(searchText.uppercased()) {
                                _cityMatchedList.append(SelectedCity(name:"\(name), \(city)", lat: obj.lat, lon: obj.lon))
                            }
                        }
                    }
                }
            }
            
        }

        self.tableView.reloadData()
    }
    
    
    //**************************************************************************************
    //
    //      Function: tableView - numberOfSections
    //   Description: Return the number of sections in the tableview
    //
    //**************************************************************************************
    func numberOfSections(in tableView: UITableView) -> Int {
        if resultsController != nil {
            return resultsController.sections?.count ?? 0
        }
        
        return 0
    }
    
    //**************************************************************************************
    //
    //      Function: numberOfRowsInSection
    //   Description: Returns the number of rows in section. Will be 1 or 0
    //
    //**************************************************************************************
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    
        if resultsController != nil {
            if let totalCities = resultsController.sections?[section].numberOfObjects {
                if searchActive {
                    return _cityMatchedList.count
                } else {
                    return totalCities
                }
            }
        }
        return 0
    }
    
    //**************************************************************************************
    //
    //      Function: tableView - cellForRowAt
    //   Description: return the city name for the row at index
    //
    //**************************************************************************************
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")! as UITableViewCell;
        
        if searchActive {
            if indexPath.row < _cityMatchedList.count {
                cell.textLabel?.text = _cityMatchedList[indexPath.row].name
            }
        } else {
            if resultsController != nil {
                let terminal = resultsController.object(at: indexPath)
                cell.textLabel?.text = "\(terminal.name), \(terminal.city)"
            } else {
                cell.textLabel?.text = "Error"
            }
        }
        
        return cell;
    }
    
    //**************************************************************************************
    //
    //      Function: tableView - didSelectRowAt
    //   Description: Fired when the user taps on a city in the city list
    //
    //**************************************************************************************
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        _selectedItem = nil

        if searchActive {
            if indexPath.row < _cityMatchedList.count {
                _selectedItem = _cityMatchedList[indexPath.row]
            }
        } else {
            if resultsController != nil {
                let city = resultsController.object(at: indexPath)
                if let name = city.name {
                    _selectedItem = SelectedCity(name: name, lat: city.lat, lon: city.lon)
                }
                
            }
        }

        // Set the new search city and change to the map tab
        if _selectedItem != nil {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.searchCity = _selectedItem
            self.tabBarController?.selectedIndex = 0
        }
    }
    
    
}


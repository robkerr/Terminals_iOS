//**************************************************************************************
//
//    Filename: TerminalTasks.swift
//     Project: Terminals
//
//      Author: Robert Kerr 
//   Copyright: Copyright © 2016 MobileToolworks. All rights reserved.
//
// Description: This is a utility class to reate and search the CoreData Terminal DB
//
//  Maintenance History
//          9/26/16      File Created
//
//**************************************************************************************

import Foundation
import CoreData
import SwiftyJSON
import MapKit

class TerminalTasks {
    
    var resultsController : NSFetchedResultsController<Terminal>!
    var context : NSManagedObjectContext!
    
    //**************************************************************************************
    //
    //      Function: init
    //   Description: As this object instantiates, go find the CoreData context
    //
    //**************************************************************************************
    init() {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            self.context = appDelegate.coreDataStack.viewContext
        } else {
            fatalError()
        }
    }
    
    
    //**************************************************************************************
    //
    //      Function: searchFromCity
    //   Description: Search for all terminals within 100K meters of a given location
    //
    //**************************************************************************************
    func searchFromCity(city : SelectedCity, distanceMeters : Double) -> [Terminal] {
        return searchFromLatLon(fromLat: city.lat, fromLon: city.lon, distanceMeters: distanceMeters)
    }
    
    //**************************************************************************************
    //
    //      Function: searchFromLatLon
    //   Description: Search for all terminals within 100K meters of lat/lon
    //
    //**************************************************************************************
    func searchFromLatLon(fromLat : Double, fromLon : Double, distanceMeters : CLLocationDistance) -> [Terminal] {
        
        var pinData = [Terminal]()
        let cityLoc = CLLocation(latitude: fromLat, longitude: fromLon)
        
        let request : NSFetchRequest<Terminal> = Terminal.fetchRequest()
        let descriptor = NSSortDescriptor(key: #keyPath(Terminal.name), ascending: true)
        request.sortDescriptors = [descriptor]
        resultsController = NSFetchedResultsController(fetchRequest: request , managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        
        do {
            try resultsController.performFetch()
            
            if let objects = resultsController.fetchedObjects {
                for obj in objects {
                    let testLoc = CLLocation(latitude: obj.lat, longitude: obj.lon)     // CLLocation for this place
                    let meters = cityLoc.distance(from: testLoc)                        // Distance from the center point passed in
                    
                    
                    if obj.name!.contains("Detroit") {
                        print("Detroit!")
                    }
                    if meters > 0 &&  meters <= distanceMeters {
                        pinData.append(obj)
                    }
                }
            }
        } catch {
            print("Error performing fetch \(error.localizedDescription)")
        }
        
        return pinData
    }
}

//**************************************************************************************
//
//      Function: importTerminals
//   Description: This extension method is used to copy the json data into the database
//                not used in the production app, as it uses a seed database instead
//
//**************************************************************************************
extension NSPersistentContainer {
    
    func importTerminals() {
        
        print("*********** importing Termainals.json ***********")
        
        performBackgroundTask { (context) in
            let request : NSFetchRequest<Terminal> = Terminal.fetchRequest()
            do {
                if try context.count(for: request) == 0 {
                    guard let terminalsURL = Bundle.main.url(forResource: "terminals",
                                                         withExtension: "json") else { return }
                    
                    let data = try Data(contentsOf: terminalsURL)
                    let json = JSON(data: data)
                    
                    var count = 0
                        
                    for item in json["terminals"].arrayValue {
                        let terminal = Terminal(context: context)
                        terminal.name = item["terminalName"].stringValue
                        
                        let city = item["city"].stringValue
                        terminal.city = city
                        terminal.country = item["country"].stringValue
                        terminal.iata = item["iata"].stringValue
                        terminal.icao = item["icao"].stringValue
                        terminal.elevation = item["elevation"].int16 ?? 0
                        terminal.gmtOffset = item["gmtOffset"].int16 ?? 0
                        terminal.tzCode = item["tzCode"].stringValue
                        terminal.tzName = item["tzName"].stringValue
                        terminal.lat = item["location"]["coordinates"][1].double ?? 0.0
                        terminal.lon = item["location"]["coordinates"][0].double ?? 0.0
                        terminal.pinType = item["pinType"].stringValue
                        
                        count += 1
                        
                    }
                    try context.save()
                    print("Imported \(count) terminals")

                }
            } catch {
                print("Error importing terminals: \(error.localizedDescription)")
            }
        }
    }
}

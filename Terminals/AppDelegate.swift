//**************************************************************************************
//
//    Filename: AppDelegate.swift
//     Project: Terminals
//
//      Author: Robert Kerr 
//   Copyright: Copyright © 2016 MobileToolworks. All rights reserved.
//
//  Maintenance History
//          5/4/16      File Created
//
//**************************************************************************************

import UIKit
import CoreData


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var coreDataStack : NSPersistentContainer!
    var searchCity : SelectedCity?

    //**************************************************************************************
    //
    //      Function: didFinishLaunchingWithOptions
    //   Description: Entry point from runtime environment. Sets up the CoreData environment
    //
    //**************************************************************************************
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        UITabBar.appearance().tintColor = UIColor.init(red: 188.0/255, green: 57.0/255, blue: 54/255.0, alpha: 1.0)
        
        // Copy the seed database, if necessary
        //copySeedDatabase()
        
        coreDataStack = NSPersistentContainer(name: "Terminals")
        coreDataStack.loadPersistentStores { (description, error) in
            if let error = error {
                print("Error creating persistent stores: \(error.localizedDescription)")
                fatalError()
            }
        }
        
        coreDataStack.importTerminals()
        coreDataStack.viewContext.automaticallyMergesChangesFromParent = true
        
        
        return true
    }

    //**************************************************************************************
    //
    //      Function: copySeedDatabase
    //   Description: If the database doesn't exist in the user writable folder, cpoy it
    //                  from the bundle
    //
    //**************************************************************************************
    func copySeedDatabase() {
        
        guard let seedDatabaseUrl = Bundle.main.url(forResource: "seed", withExtension: "sqlite") else { return }
        
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let targetUrl = documentsDirectory.appendingPathComponent("Terminals.sqlite")
        
        
       if !FileManager.default.fileExists(atPath: targetUrl.path) {

            do {
                let isFolder : UnsafeMutablePointer<ObjCBool>? = nil
                
                if !FileManager.default.fileExists(atPath: documentsDirectory.path, isDirectory:isFolder) {
                    try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
                }
                // try will fail if the file already exists
                //let data = try Data(contentsOf: seedDatabaseUrl)
                
                try FileManager.default.copyItem(atPath: seedDatabaseUrl.path, toPath: targetUrl.path)
                //try FileManager.default.copyItem(at: seedDatabaseUrl, to: targetUrl)
                print("Copied file OK")
            } catch let error  {
                print("Error copying seed database: \(error.localizedDescription)")
            }
        }
        
    }
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}


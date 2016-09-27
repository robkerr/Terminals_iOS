//**************************************************************************************
//
//    Filename: BrowseMapVC.swift
//     Project: Terminals
//
//      Author: Robert Kerr 
//   Copyright: Copyright © 2016 MobileToolworks. All rights reserved.
//
//  Maintenance History
//          5/2/16      File Created
//          9/26/16     Converted to use CoreData instead of MongoDB/AWS
//
//**************************************************************************************

import UIKit
import MapKit
import CoreData

class BrowseMapVC: UIViewController,  MKMapViewDelegate, CLLocationManagerDelegate, UIAlertViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var toggleMapTypeButton: UIButton!
    
    var manager: CLLocationManager?
    
    // The center position of the map when displayed
    var centerLat = 0.0
    var centerLon = 0.0
    var pins: [Terminal] = []
    
    var nextRegionChangeFromUser = false
    
    
    //**************************************************************************************
    //
    //      Function: viewDidLoad
    //   Description: on load, initialize the location manager, set delegate
    //
    //**************************************************************************************
    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        
        manager = CLLocationManager()
        manager?.delegate = self;
        manager?.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    //**************************************************************************************
    //
    //      Function: viewDidAppear
    //   Description: As form appears, perform a search (if city is specified)
    //                  if no city search, locate the user so the current lat/lon can be
    //                  used for the center of the search
    //
    //**************************************************************************************
    override func viewDidAppear(_ animated: Bool) {
        
        // Set the correct image based on the current mapType
        if mapView.mapType == .standard {
            toggleMapTypeButton.setImage(UIImage.init(named: "Satellite"), for: UIControlState())
        } else {
            toggleMapTypeButton.setImage(UIImage.init(named: "MapFilled"), for: UIControlState())
        }


        // If there is a search city, kick off a query for it. Otherwise kick off a query of current Geo Location
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        if let city = appDelegate.searchCity {
            let task = TerminalTasks()
            pins = task.searchFromCity(city: city, distanceMeters: 100_000)
            addPins(true)
            
        } else {
            if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
                manager?.requestWhenInUseAuthorization()
                manager?.startUpdatingLocation()
            }
        }
    }
    
    
    //**************************************************************************************
    //
    //      Function: didUpdateLocations
    //   Description: When we get a location update with our level of accuracy, 
    //                  stop the gps
    //
    //**************************************************************************************
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
        
        if locations.count > 0 {
            let loc = locations[0]
        
            let task = TerminalTasks()
            pins = task.searchFromLatLon(fromLat: loc.coordinate.latitude, fromLon: loc.coordinate.longitude, distanceMeters: 100_000)
            addPins(true)
        }
    }

    //**************************************************************************************
    //
    //      Function: regionWillChangeAnimated
    //   Description: As the user pans around, update the query and the map
    //
    //**************************************************************************************
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let view = mapView.subviews.first
        
        for recognizer in (view?.gestureRecognizers)! {
            if recognizer.state == .began || recognizer.state == .ended {
                self.nextRegionChangeFromUser = true
                break
            }
        }
    }
    
    
    //**************************************************************************************
    //
    //      Function: toggleMapTypeTapped
    //   Description: User has decided to toggle the map
    //
    //**************************************************************************************
    @IBAction func toggleMapTypeTapped(_ sender: UIButton) {
        
        if mapView.mapType == .standard {
            toggleMapTypeButton.setImage(UIImage.init(named: "MapFilled"), for: UIControlState())
            mapView.mapType = .hybrid
        } else {
            toggleMapTypeButton.setImage(UIImage.init(named: "Satellite"), for: UIControlState())
            mapView.mapType = .standard
        }
    }
    
    //**************************************************************************************
    //
    //      Function: CenterMapOnMeTapped
    //   Description: Center the map on the user's current location
    //
    //**************************************************************************************
    @IBAction func CenterMapOnMeTapped(_ sender: UIButton) {
        if CLLocationManager.authorizationStatus() != .authorizedWhenInUse {
            showLocationAcessDeniedAlert()
        } else {
            if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
                manager?.requestWhenInUseAuthorization()
                manager?.startUpdatingLocation()
            }
        }
    }

    //**************************************************************************************
    //
    //      Function: showLocationAcessDeniedAlert
    //   Description: If the app has been denied by the user, show an error message
    //
    //**************************************************************************************
    func showLocationAcessDeniedAlert() {
        let alertController = UIAlertController(title: "Location Permission",
                                                message: "Permission to determine your current location was not authorized. Please enable it in Settings to continue.",
                                                preferredStyle: .alert)
        
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (alertAction) in
            
            if let appSettings = URL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
 
            }
        }
        alertController.addAction(settingsAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    //**************************************************************************************
    //
    //      Function: regionDidChangeAnimated
    //   Description: When the region has changed, requery the nearby data locations
    //
    //**************************************************************************************
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {

        if self.nextRegionChangeFromUser {
            self.nextRegionChangeFromUser = false
            
            // Get the center and meters in the x and y dimensions of the span
            let span = mapView.region.span
            let center = mapView.region.center
            
            let loc1 = CLLocation(latitude: center.latitude - span.latitudeDelta * 0.5, longitude: center.longitude)
            let loc2 = CLLocation(latitude: center.latitude + span.latitudeDelta * 0.5, longitude: center.longitude)
            let loc3 = CLLocation(latitude: center.latitude, longitude: center.longitude - span.longitudeDelta * 0.5)
            let loc4 = CLLocation(latitude: center.latitude, longitude: center.longitude + span.longitudeDelta * 0.5)
            
            let metersInLatitude = loc1.distance(from: loc2)
            let metersInLongitude = loc3.distance(from: loc4)
            
            // Pick out the shortest of lat and lon dimensions
            var distanceInMeters = metersInLongitude / 2.0
            
            if metersInLatitude > metersInLongitude {
                distanceInMeters = metersInLatitude / 2.0
            }
            
            if distanceInMeters < 500000 {
                let task = TerminalTasks()
                pins = task.searchFromLatLon(fromLat: center.latitude, fromLon: center.longitude, distanceMeters: 100_000)
                addPins(true)
            }
        }
        
    }
    

    //**************************************************************************************
    //
    //      Function: addPins
    //   Description: Called internally to add the current set of pins to the map
    //
    //**************************************************************************************
    func addPins(_ autoZoom : Bool) {
        
        // remove all annotations currently dropped
        DispatchQueue.main.async(execute: { () -> Void in
            self.mapView.removeAnnotations(self.mapView.annotations)
        })
        
        // re-add annotations
        for pin in pins {
            
            let name = pin.name ?? "Unknown"
            let city = pin.city ?? "Unknown"
            var iconName = ""
            
            // Build the icon name based on the data value
            if let pinType = pin.pinType {
                iconName = "Pin_\(pinType)"
            }
            
            // If the build icon name is invalid, just assign a civilian airport icon to it
            if !["Pin_CivilianAirport", "Pin_SeaPort", "Pin_BusStation", "Pin_RailStation", "Pin_MilitaryAirport"].contains(iconName) {
                iconName = "Pin_CivilianAirport"
            }
            
            // Create the annotation, add to the map
            let annotation = CustomAnnotation(coordinate: CLLocationCoordinate2DMake(pin.lat, pin.lon),
                                              title: name,
                                              subtitle: city,
                                              iconName: iconName)
            
            DispatchQueue.main.async(execute: { () -> Void in
                self.mapView.addAnnotation(annotation)
            })
        }
        
        if autoZoom {
            zoomMapViewToFitAnnotations(true)
        }
        
    }
    
    // helpers to avoid trying to add pins for invalid coordinates
    func validLat(_ lat : Double) -> Bool {
        if lat >= -90.0 && lat <= 90.0 {
            return true
        }
        
        return false
    }
    func validLon(_ lat : Double) -> Bool {
        if lat >= -180.0 && lat <= 180.0 {
            return true
        }
        
        return false
    }
    
    //**************************************************************************************
    //
    //      Function: zoomMapViewToFitAnnotations
    //   Description: Zoom the map bounding box to fit the annotations
    //
    //**************************************************************************************
    func zoomMapViewToFitAnnotations(_ animated: Bool) {
        let MINIMUM_ZOOM_ARC = 0.014 //approximately 1 miles (1 degree of arc ~= 69 miles)
        let ANNOTATION_REGION_PAD_FACTOR = 1.15
        let MAX_DEGREES_ARC = 360.0
        
        let count = pins.count
        
        //bail if no annotations
        if count == 0 {
            return
        }
        
        // Build array of MKMapPoint from the stations
        var points = [CLLocationCoordinate2D]()
        
        for pin in self.pins {
            
            
            if validLat(pin.lat) && validLon(pin.lon) {
                points.append(CLLocationCoordinate2DMake(pin.lat, pin.lon))
            }
        }
        
        if points.count == 0 {
            return
        }

        if points.count == 1 {
            let region = MKCoordinateRegionMakeWithDistance(points[0], 10000, 10000)
            
            // dispatch update of view on UI thread
            DispatchQueue.main.async(execute: { () -> Void in
                self.mapView.setRegion(region, animated: animated)
            })
        } else {
            //create polygon from array of valid coordinates
            let polygon = MKPolygon(coordinates: &points, count: points.count)
            let mapRect = polygon.boundingMapRect
            var region = MKCoordinateRegionForMapRect(mapRect)
            
            // Add some padding
            region.span.latitudeDelta *= ANNOTATION_REGION_PAD_FACTOR
            region.span.longitudeDelta *= ANNOTATION_REGION_PAD_FACTOR
            
            // Check for padding making the region bigger then the world
            if region.span.latitudeDelta > MAX_DEGREES_ARC {
                region.span.latitudeDelta  = MAX_DEGREES_ARC
            }
            if region.span.longitudeDelta > MAX_DEGREES_ARC {
                region.span.longitudeDelta  = MAX_DEGREES_ARC
            }
            
            // And don't zoom in *too* much
            if points.count == 1 || region.span.latitudeDelta < MINIMUM_ZOOM_ARC {
                region.span.latitudeDelta  = MINIMUM_ZOOM_ARC
            }
            if points.count == 1 || region.span.longitudeDelta < MINIMUM_ZOOM_ARC {
                region.span.longitudeDelta  = MINIMUM_ZOOM_ARC
            }
            
            // dispatch update of view on UI thread
            DispatchQueue.main.async(execute: { () -> Void in
                self.mapView.setRegion(region, animated: animated)
            })
        }
    }
    
    
    //**************************************************************************************
    //
    //      Function: viewFor annotation
    //   Description: Returns a view appropriate for the given annotation
    //
    //**************************************************************************************
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        // Below condition is for custom annotation
        if (annotation is CustomAnnotation) {
            let customAnnotation = annotation as? CustomAnnotation
            
            if let reuseId = customAnnotation?.iconName {
                var av = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as MKAnnotationView!
                
                if (av == nil) {
                    av = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                    av?.image = UIImage(named: customAnnotation!.iconName)
                    av?.canShowCallout = true
                } else {
                    av?.annotation = annotation;
                }
                
                self.addBounceAnimationToView(av!)
                return av
            }
        }
        return nil
    }
    
    //**************************************************************************************
    //
    //      Function: addBounceAnimationToView
    //   Description: Adds a bounce animation as a pin is dropped
    //
    //**************************************************************************************
    func addBounceAnimationToView(_ view: UIView) {
        let bounceAnimation = CAKeyframeAnimation(keyPath: "transform.scale") as CAKeyframeAnimation
        bounceAnimation.values = [ 0.05, 1.1, 0.9, 1]
        
        var timingFunctions = [CAMediaTimingFunction]()
        
        for _ in 0 ..< bounceAnimation.values!.count {
            timingFunctions.append(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
        }
        bounceAnimation.timingFunctions = timingFunctions
        bounceAnimation.isRemovedOnCompletion = false
        
        view.layer.add(bounceAnimation, forKey: "bounce")
    }

}

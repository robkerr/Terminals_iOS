//
//  BrowseMapVC.swift
//  Terminals
//
//  Created by Robert Kerr on 5/2/16.
//  Copyright © 2016 MobileToolworks. All rights reserved.
//

import UIKit
import MapKit
import Alamofire
import SwiftyJSON
import Mixpanel


struct PinData {
    var terminalName : String
    var city : String
    var country : String?
    var iata : String?
    var icao : String?
    var gmtOffset : Int?
    var tzCode : String?
    var tzName : String?
    var elevation : Int?
    var pinType : String = "Pin_CivilianAirport"
    var location : CLLocationCoordinate2D
    
    init(terminalName : String, city: String, country : String?, iata : String?, icao : String?, pinType: String?, gmtOffset : Int?, tzCode : String?, tzName : String?, elevation : Int?, coordinates : (Double, Double)) {
        
        self.terminalName = terminalName
        self.city = city
        self.country = country
        self.iata = iata
        self.icao = icao
        
        if let p = pinType {
            if ["BusStation", "RailStation", "MilitaryAirport", "SeaPort"].contains(p) {
                self.pinType = "Pin_" + p
            }
        }
        
        self.gmtOffset = gmtOffset
        self.tzCode = tzCode
        self.tzName = tzName
        self.elevation = elevation
        self.location = CLLocationCoordinate2DMake(coordinates.0, coordinates.1)
    }
}

class BrowseMapVC: UIViewController,  MKMapViewDelegate, CLLocationManagerDelegate, UIAlertViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    
    @IBOutlet weak var toggleMapTypeButton: UIButton!
    
    
    
    var manager: CLLocationManager?
    
    // The center position of the map when displayed
    var centerLat = 0.0
    var centerLon = 0.0
    var pins: [PinData] = []
    
    var nextRegionChangeFromUser = false
    
    // If provided, use the lat/lon of this city as the center position of the map
    var baseUrl = "https://demo.mobiletoolworks.com/terminals/"

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        
        manager = CLLocationManager()
        manager?.delegate = self;
        manager?.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    override func viewDidAppear(animated: Bool) {
        
        let mixpanel = Mixpanel.sharedInstance()
        mixpanel.track("Browse Map Appeared")

        // Set the correct image based on the current mapType
        if mapView.mapType == .Standard {
            toggleMapTypeButton.setImage(UIImage.init(named: "Satellite"), forState: .Normal)
        } else {
            toggleMapTypeButton.setImage(UIImage.init(named: "MapFilled"), forState: .Normal)
        }


        // If there is a search city, kick off a query for it. Otherwise kick off a query of current Geo Location
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate

        if let city = appDelegate.searchCity {

            // If have a city, use it to search for the list of points
            let url = self.baseUrl + "searchFromCity"
            let parameters : [String : AnyObject] = [
                "distanceMeters" : 100000,
                "city" : city
            ]
            
            SendQuery(url, parameters: parameters, autoZoom: true)
            
        } else {

            if CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion) {
                manager?.requestWhenInUseAuthorization()
                manager?.startUpdatingLocation()
            }
        }
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        manager.stopUpdatingLocation()
        
        // If have a city, use it to search for the list of points
        let url = self.baseUrl + "searchFromPoint"
        let parameters : [String : AnyObject] = [
            "distanceMeters" : 100000,
            "lat" : locations[0].coordinate.latitude,
            "lon" : locations[0].coordinate.longitude
        ]
        
        SendQuery(url, parameters: parameters, autoZoom: true)
        
    }

    func mapView(mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let view = mapView.subviews.first
        
        for recognizer in (view?.gestureRecognizers)! {
            if recognizer.state == .Began || recognizer.state == .Ended {
                self.nextRegionChangeFromUser = true
                break
            }
        }
    }
    
    
    @IBAction func toggleMapTypeTapped(sender: UIButton) {
        
        if mapView.mapType == .Standard {
            toggleMapTypeButton.setImage(UIImage.init(named: "MapFilled"), forState: .Normal)
            mapView.mapType = .Hybrid
        } else {
            toggleMapTypeButton.setImage(UIImage.init(named: "Satellite"), forState: .Normal)
            mapView.mapType = .Standard
        }
    }
    
    @IBAction func CenterMapOnMeTapped(sender: UIButton) {
        if CLLocationManager.authorizationStatus() != .AuthorizedWhenInUse {
            showLocationAcessDeniedAlert()
        } else {
            if CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion) {
                manager?.requestWhenInUseAuthorization()
                manager?.startUpdatingLocation()
            }
        }
    }

    func showLocationAcessDeniedAlert() {
        let alertController = UIAlertController(title: "Location Permission",
                                                message: "Permission to determine your current location was not authorized. Please enable it in Settings to continue.",
                                                preferredStyle: .Alert)
        
        let settingsAction = UIAlertAction(title: "Settings", style: .Default) { (alertAction) in
            
            if let appSettings = NSURL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.sharedApplication().openURL(appSettings)
            }
        }
        alertController.addAction(settingsAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {

        if self.nextRegionChangeFromUser {
            self.nextRegionChangeFromUser = false
            
            // Get the center and meters in the x and y dimensions of the span
            let span = mapView.region.span
            let center = mapView.region.center
            
            let loc1 = CLLocation(latitude: center.latitude - span.latitudeDelta * 0.5, longitude: center.longitude)
            let loc2 = CLLocation(latitude: center.latitude + span.latitudeDelta * 0.5, longitude: center.longitude)
            let loc3 = CLLocation(latitude: center.latitude, longitude: center.longitude - span.longitudeDelta * 0.5)
            let loc4 = CLLocation(latitude: center.latitude, longitude: center.longitude + span.longitudeDelta * 0.5)
            
            let metersInLatitude = loc1.distanceFromLocation(loc2)
            let metersInLongitude = loc3.distanceFromLocation(loc4)
            
            // Pick out the shortest of lat and lon dimensions
            var distanceInMeters = metersInLongitude / 2.0
            
            if metersInLatitude > metersInLongitude {
                distanceInMeters = metersInLatitude / 2.0
            }
            
            if distanceInMeters < 500000 {
                // Build the request paramters
                var url = self.baseUrl
                var parameters : [String : AnyObject] = [
                    "distanceMeters" : distanceInMeters
                ]
                
                url.appendContentsOf("searchFromPoint")
                parameters["lat"] = center.latitude;
                parameters["lon"] = center.longitude;
                
                SendQuery(url, parameters: parameters, autoZoom: false)
            }
        }
        
    }
    
    /**************************************************
     
     Send query to web service and process results
     
     **************************************************/
    func SendQuery(url : String, parameters : [String : AnyObject], autoZoom : Bool) {
    
        self.pins.removeAll()

        // always sending JSON
        let headers : [String : String] = [
            "Content-Type": "application/json"
        ]
        
        let mixpanel = Mixpanel.sharedInstance()
        mixpanel.timeEvent("pinQuery")

        
        Alamofire.request(.POST, url, headers: headers, parameters: parameters, encoding: .JSON)
            .responseJSON { response in
                
                mixpanel.track("pinQuery")
            
                if response.result.isFailure {
                    
                    if response.result.error?.code != 3840 {
                        let alertController = UIAlertController(title: "Network Error",
                            message: response.result.error?.localizedDescription, preferredStyle: .Alert)
                        
                        let OKAction = UIAlertAction(title: "OK", style: .Default) { (action:UIAlertAction!) in
                        }
                        alertController.addAction(OKAction)
                        
                        self.presentViewController(alertController, animated: true, completion:nil)
                    }
                } else {
                    
                    if let statusCode = response.response?.statusCode {
                        
                        if statusCode != 200 {
                            var errorMessage = "Error \(statusCode)"
                            
                            if let dict = response.result.value as? [String:AnyObject], msg = dict["Message"] as? String {
                                errorMessage = "Error \(statusCode): \(msg)"
                            }
                            
                            let alertController = UIAlertController(title: "Network Error",
                                message: errorMessage, preferredStyle: .Alert)
                            
                            let OKAction = UIAlertAction(title: "OK", style: .Default) { (action:UIAlertAction!) in
                            }
                            alertController.addAction(OKAction)
                            
                            self.presentViewController(alertController, animated: true, completion:nil)
                            
                        } else {
                            
                            if let responseJson = response.result.value {
                                let json = JSON(responseJson)
                                
                                if let jsonArray = json.array {
                                    for terminal in jsonArray {
                                        
                                        let longitude = terminal["location"]["coordinates"][0].doubleValue
                                        let latitude = terminal["location"]["coordinates"][1].doubleValue
                                        
                                        if self.validLon(longitude) && self.validLat(latitude) {
                                            
                                            let pin = PinData(
                                                terminalName: terminal["terminalName"].stringValue,
                                                city: terminal["city"].stringValue,
                                                country: terminal["country"].stringValue,
                                                iata: terminal["iata"].stringValue,
                                                icao: terminal["icao"].stringValue,
                                                pinType: terminal["pinType"].stringValue,
                                                gmtOffset: terminal["gmtOffset"].intValue,
                                                tzCode: terminal["tzCode"].stringValue,
                                                tzName: terminal["tzName"].stringValue,
                                                elevation: terminal["elevation"].intValue,
                                                coordinates: (latitude, longitude))
                                            
                                            self.pins.append(pin)
                                        }
                                    }
                                }
                            }
                            
                            self.addPins(autoZoom)
                        }
                    }
                }
        }
    }

    func addPins(autoZoom : Bool) {
        
        // remove all annotations currently dropped
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.mapView.removeAnnotations(self.mapView.annotations)
        })
        
        // re-add annotations
        for pin in pins {
            
            // Todo: Determine which pin image to use
            let iconName = pin.pinType
            
            let annotation = CustomAnnotation(coordinate: pin.location, title: pin.terminalName, subtitle: pin.city, iconName: iconName)
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.mapView.addAnnotation(annotation)
            })
        }
        
        if autoZoom {
            zoomMapViewToFitAnnotations(true)
        }
        
    }
    
    // helpers to avoid trying to add pins for invalid coordinates
    func validLat(lat : Double) -> Bool {
        if lat >= -90.0 && lat <= 90.0 {
            return true
        }
        
        return false
    }
    func validLon(lat : Double) -> Bool {
        if lat >= -180.0 && lat <= 180.0 {
            return true
        }
        
        return false
    }
    
    func zoomMapViewToFitAnnotations(animated: Bool) {
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
            if validLat(pin.location.latitude) && validLon(pin.location.longitude) {
                points.append(pin.location)
            }
        }
        
        if points.count == 0 {
            return
        }

        if points.count == 1 {
            let region = MKCoordinateRegionMakeWithDistance(points[0], 10000, 10000)
            
            // dispatch update of view on UI thread
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
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
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.mapView.setRegion(region, animated: animated)
            })
        }
    }
    
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        
        // Below condition is for custom annotation
        if (annotation is CustomAnnotation) {
            let customAnnotation = annotation as? CustomAnnotation
            
            if let reuseId = customAnnotation?.iconName {
                var av = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as MKAnnotationView!
                
                if (av == nil) {
                    av = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                    av.image = UIImage(named: customAnnotation!.iconName)
                    av.canShowCallout = true
                } else {
                    av.annotation = annotation;
                }
                
                self.addBounceAnimationToView(av)
                return av
            }
        }
        return nil
    }
    
    func addBounceAnimationToView(view: UIView) {
        let bounceAnimation = CAKeyframeAnimation(keyPath: "transform.scale") as CAKeyframeAnimation
        bounceAnimation.values = [ 0.05, 1.1, 0.9, 1]
        
        var timingFunctions = [CAMediaTimingFunction]()
        
        for _ in 0 ..< bounceAnimation.values!.count {
            timingFunctions.append(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
        }
        bounceAnimation.timingFunctions = timingFunctions
        bounceAnimation.removedOnCompletion = false
        
        view.layer.addAnimation(bounceAnimation, forKey: "bounce")
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}

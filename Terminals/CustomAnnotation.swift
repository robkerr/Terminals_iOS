import UIKit
import MapKit

class CustomAnnotation : NSObject, MKAnnotation {
    
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var iconName: String
    
    init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String, iconName: String) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
    }
}
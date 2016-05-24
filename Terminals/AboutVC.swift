//
//  AboutVC.swift
//  Terminals
//
//  Created by Robert Kerr on 5/6/16.
//  Copyright © 2016 MobileToolworks. All rights reserved.
//

import UIKit
import Mixpanel

class AboutVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(animated: Bool) {
        let mixpanel = Mixpanel.sharedInstance()
        mixpanel.track("About Appeared")

    }
    
    override func  preferredStatusBarStyle()-> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }

}

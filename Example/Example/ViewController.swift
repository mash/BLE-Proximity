//
//  ViewController.swift
//  Example
//
//  Created by Masakazu Ohtsuka on 2020/04/08.
//  Copyright © 2020 maaash.jp. All rights reserved.
//

import UIKit
import BProximity

class ViewController: UIViewController {
    var askedPermission :Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if (!askedPermission) {
            // Ask for permission
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "AskPermissionViewController") as AskPermissionViewController
            vc.input = .Bluetooth
            vc.output = { (vc) in
                BProximity.start()
                vc.dismiss(animated: true)
            }
            self.present(vc, animated: true)
        }
        else {
            BProximity.start()
        }
    }
}

//
//  AskPermissionViewController.swift
//  ExampleDevelopment
//
//  Created by Masakazu Ohtsuka on 2020/04/08.
//  Copyright © 2020 maaash.jp. All rights reserved.
//

import Foundation
import UIKit

class AskPermissionViewController: UIViewController {
    enum PermissionType {
        case Location
        case Bluetooth
        func labelText() -> String {
            switch self {
            case .Location:
                return "Allow using location ?"
            case .Bluetooth:
                return "Allow using Bluetooth ?"
            }
        }
    }
    typealias Completed = (AskPermissionViewController) -> ()

    var input :PermissionType!
    var output :Completed!

    @IBOutlet weak var mainLabel: UILabel!
    @IBOutlet weak var allowButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        mainLabel.text = input.labelText()
    }

    @IBAction func allowButtonPressed(_ sender: Any) {
        output(self)
    }
}

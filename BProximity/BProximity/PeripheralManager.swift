//
//  PeripheralManager.swift
//  BProximity
//
//  Created by Masakazu Ohtsuka on 2020/04/09.
//  Copyright © 2020 maaash.jp. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol PeripheralManagerDelegate :class {
}

class PeripheralManager :NSObject {
    let peripheralManager :CBPeripheralManager
    weak var delegate :PeripheralManagerDelegate!
    init(delegate: PeripheralManagerDelegate) {
        peripheralManager = CBPeripheralManager(delegate: nil, queue: nil)
        super.init()
        peripheralManager.delegate = self
    }

    func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }
}

extension PeripheralManager :CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        log("state=\(peripheral.state)")
        if peripheral.state == .poweredOn {
            startAdvertising()
        }
    }
    func startAdvertising() {
        let advertisementData = [
            CBAdvertisementDataServiceUUIDsKey: [Service.BProximity.toCBUUID()]
        ]
        peripheralManager.startAdvertising(advertisementData)
    }
}

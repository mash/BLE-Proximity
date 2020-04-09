//
//  CentralManager.swift
//  BProximity
//
//  Created by Masakazu Ohtsuka on 2020/04/09.
//  Copyright © 2020 maaash.jp. All rights reserved.
//

import Foundation
import CoreBluetooth

enum Command {
    case Read(from :Characteristic)
    case Write(to :Characteristic, value :()->(Data))
}

class CentralManager :NSObject {
    let centralManager :CBCentralManager
    let services :[CBUUID]!
    var commands :[Command] = []
    var peripherals :[Peripheral] = []
    var updateValueCallback :DidUpdateValue?
    init(services :[CBUUID]) {
        let options = [CBCentralManagerOptionShowPowerAlertKey: 1]
        centralManager = CBCentralManager(delegate: nil, queue: nil, options: options)
        self.services = services
        super.init()
    }

    func startScanning() {
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(booleanLiteral: true)]
        centralManager.scanForPeripherals(withServices: services, options: options)
    }

    func stopScan() {
        centralManager.stopScan()
    }

    func readValue(from :Characteristic) -> CentralManager {
        self.commands.append(.Read(from: from))
        return self // for chaining
    }

    func writeValue(to :Characteristic, value :@escaping ()->(Data)) -> CentralManager {
        self.commands.append(.Write(to: to, value: value))
        return self
    }

    func didUpdateValue(_ callback:@escaping (Characteristic, Data?, Error?)->()) -> CentralManager {
        updateValueCallback = callback
        return self
    }
}

extension CentralManager :CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("state=\(central.state)")
        if central.state == .poweredOn {
            startScanning()
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        log("peripheral=\(peripheral)")

        let p = Peripheral(peripheral: peripheral, services: services, commands: commands, callback: updateValueCallback)
        peripherals.append(p)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("peripheral=\(peripheral), error=\(String(describing: error))")
        peripherals = peripherals.filter { (p) -> Bool in p.id == peripheral.identifier }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        log("peripheral=\(peripheral), ad=\(advertisementData), rssi=\(RSSI)")
        central.connect(peripheral, options: nil)
        // TODO record max RSSI
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("peripheral=\(peripheral), error=\(String(describing: error))")
    }
}

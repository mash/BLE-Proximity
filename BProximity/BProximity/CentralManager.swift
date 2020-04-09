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
    private var started :Bool = false
    private let centralManager :CBCentralManager
    private let services :[CBUUID]!
    private var commands :[Command] = []
    private var peripherals :[UUID:Peripheral] = [:]
    private var didUpdateValue :DidUpdateValue?

    init(services :[CBUUID]) {
        let options = [CBCentralManagerOptionShowPowerAlertKey: 1]
        centralManager = CBCentralManager(delegate: nil, queue: nil, options: options)
        self.services = services
        super.init()
        centralManager.delegate = self
    }

    func start() {
        started = true
        startScanning()
    }

    func stop() {
        started = false
        stopScan()
    }

    private func startScanning() {
        guard centralManager.state == .poweredOn else { return }

        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(booleanLiteral: true)]
        centralManager.scanForPeripherals(withServices: services, options: options)
    }

    private func stopScan() {
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
        didUpdateValue = callback
        return self
    }
}

extension CentralManager :CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("state=\(central.state)")
        if central.state == .poweredOn && started {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("peripheral=\(peripheral)")

        let p = peripherals[peripheral.identifier]
        if let p = p {
            p.discoverServices()
        }
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("peripheral=\(peripheral), error=\(String(describing: error))")
        peripherals.removeValue(forKey: peripheral.identifier)
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        log("peripheral=\(peripheral.identifier), rssi=\(RSSI)")
        if peripherals[peripheral.identifier] == nil {
            let p = Peripheral(peripheral: peripheral, services: services, commands: commands, callback: didUpdateValue)
            peripherals[peripheral.identifier] = p
            central.connect(peripheral, options: nil)
        }
        // TODO record max RSSI
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("peripheral=\(peripheral), error=\(String(describing: error))")
    }
}

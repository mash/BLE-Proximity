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
    case Read(from :Characteristic, didUpdate :DidUpdateValue)
    case Write(to :Characteristic, value :()->(Data))
    case Cancel(callback :(Peripheral)->())
}

class CentralManager :NSObject {
    private var started :Bool = false
    private var centralManager :CBCentralManager!
    private let services :[CBUUID]!
    private var commands :[Command] = []
    private var peripherals :[UUID:Peripheral] = [:]

    init(services :[CBUUID]) {
        self.services = services
        super.init()
        let options = [CBCentralManagerOptionShowPowerAlertKey: 1, CBCentralManagerOptionRestoreIdentifierKey: "CentralManager"] as [String : Any]
        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
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

    func appendCommand(command :Command) -> CentralManager {
        self.commands.append(command)
        return self // for chaining
    }

    func disconnect(_ peripheral :Peripheral) {
        centralManager.cancelPeripheralConnection(peripheral.peripheral)
    }

    func addPeripheral(_ peripheral :CBPeripheral) {
        let p = Peripheral(peripheral: peripheral, services: services, commands: commands)
        peripherals[peripheral.identifier] = p
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
            addPeripheral(peripheral)
            central.connect(peripheral, options: nil)
        }
        // TODO record max RSSI
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("peripheral=\(peripheral), error=\(String(describing: error))")
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        log("dict=\(dict)")

        // Hmm, no we want to reconnect to them and re-record the proximity event
//        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
//            peripherals.forEach { (peripheral) in
//                addPeripheral(peripheral)
//            }
//        }
    }
}

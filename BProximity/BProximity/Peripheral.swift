//
//  Peripheral.swift
//
//  Created by Masakazu Ohtsuka on 2014/11/05.
//  Copyright (c) 2014年 Masakazu Ohtsuka. All rights reserved.
//

import Foundation
import CoreBluetooth

typealias DidUpdateValue = (Characteristic, Data?, Error?)->()

let PeripheralDidUpdateValueNotification = "PeripheralDidUpdateValueNotification"
let PeripheralCharactersticUserInfoKey = "PeripheralCharactersticUserInfoKey"

class Peripheral: NSObject {
    let peripheral :CBPeripheral!
    private let services :[CBUUID]
    private var commands :[Command]
    private var currentCommand :Command?
    public var id :UUID {
        return peripheral.identifier
    }

    init(peripheral: CBPeripheral, services :[CBUUID], commands :[Command]) {
        self.peripheral = peripheral
        self.commands = commands
        self.services = services
        super.init()
        self.peripheral.delegate = self
    }

    func discoverServices() {
        peripheral.discoverServices(services)
    }

    func nextCommand() {
        if commands.count == 0 {
            currentCommand = nil
            return
        }
        log()
        currentCommand = commands[0]
        commands = commands.shift()
        execute(currentCommand!)
    }

    func execute(_ command :Command) {
        switch command {
        case .Read(let from, _):
            if let ch = toCBCharacteristic(c12c: from) {
                peripheral.readValue(for: ch)
            }
            break
        case .Write(let to, let value):
            if let ch = toCBCharacteristic(c12c: to) {
                peripheral.writeValue(value(), for: ch, type: .withoutResponse)
            }
            nextCommand()
            break
        case .Cancel(let callback):
            callback(self)
            break
        }
    }

    func writeValue(value :Data, forCharacteristic ch :Characteristic, type :CBCharacteristicWriteType) {
        if let c = self.toCBCharacteristic(c12c: ch) {
            self.peripheral.writeValue(value, for: c, type: type)
        }
        else {
            log("c12c=\(ch) not found")
        }
    }

    func readValueForCharacteristic(c12c :Characteristic) throws {
        guard let c = self.toCBCharacteristic(c12c: c12c) else {
            log("c12c=\(c12c) not found")
            return
        }
        log("reading=\(c12c)")
        self.peripheral.readValue(for: c)
    }

    // MARK: - private utilities

    func toCBCharacteristic(c12c :Characteristic) -> CBCharacteristic? {
        let findingC12CUUID = c12c.toCBUUID()
        let findingServiceUUID = c12c.toService().toCBUUID()
        if let services = self.peripheral.services {
            let foundService = services.first { service in
                return findingServiceUUID.isEqual(service.uuid)
            }
            if let c12cs = foundService?.characteristics {
                return c12cs.first { c in
                    return findingC12CUUID.isEqual(c.uuid)
                }
            }
        }
        return nil
    }
}

extension Peripheral :CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        log("services=\(String(describing: peripheral.services)), error=\(String(describing: error))")
        guard let services = peripheral.services else { return }

        for service in services {
            // There are cases when there are many BProximity services in the array.
            // We only need to discover characteristics for one of them.
            if case .BProximity = Service.init(rawValue: service.uuid.uuidString) {
                peripheral.discoverCharacteristics(nil, for: service)
                return
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        log("service=\(service), ch=\(String(describing: service.characteristics)), error=\(String(describing: error))")
        if let _ = error {
            return
        }

        nextCommand()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        log("peripheral=\(peripheral.identifier), ch=\(String(describing: Characteristic.fromCBCharacteristic(characteristic)))")
        if let ch = Characteristic.fromCBCharacteristic(characteristic) {
            if case .Read(_, let didUpdate) = currentCommand {
                didUpdate(ch, characteristic.value, error)

                // Read complete
                nextCommand()
            }
        }
    }
}

extension Array {
    public func shift() -> Array {
        if count == 0 {
            return []
        }
        return Array(self[1..<self.count])
    }
}

//
//  Peripheral.swift
//
//  Created by Masakazu Ohtsuka on 2014/11/05.
//  Copyright (c) 2014年 Masakazu Ohtsuka. All rights reserved.
//

import Foundation
import CoreBluetooth

struct CharacteristicAndError {
    let characteristic :CBCharacteristic
    let error :NSError?
}

typealias DidUpdateValue = (Characteristic, Data?, Error?)->()

let PeripheralDidUpdateValueNotification = "PeripheralDidUpdateValueNotification"
let PeripheralCharactersticUserInfoKey = "PeripheralCharactersticUserInfoKey"

class Peripheral: NSObject, CBPeripheralDelegate {
    private let peripheral :CBPeripheral!
    private let commands :[Command]
    private let callback :DidUpdateValue?
    public var id :UUID {
        return peripheral.identifier
    }

    init(peripheral: CBPeripheral, services :[CBUUID]?, commands :[Command], callback :DidUpdateValue?) {
        self.peripheral = peripheral
        self.commands = commands
        self.callback = callback
        super.init()
        self.peripheral.delegate = self
        self.peripheral.discoverServices(services)
    }

    deinit {
        log()
    }

    func dispatch() {
        log()
        commands.forEach { (command) in
            execute(command)
        }
    }

    func execute(_ command :Command) {
        switch command {
        case .Read(let from):
            if let ch = toCBCharacteristic(c12c: from) {
                peripheral.readValue(for: ch)
            }
            break
        case .Write(let to, let value):
            if let ch = toCBCharacteristic(c12c: to) {
                peripheral.writeValue(value(), for: ch, type: .withoutResponse)
            }
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
            // throw(Error(domain: BoccoErrorDomain, code: BoccoErrorCodeC12CNotFound, userInfo: nil))
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

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        log("services=\(String(describing: peripheral.services))")
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        log("service=\(service), ch=\(String(describing: service.characteristics)), error=\(String(describing: error))")
        if let _ = error {
            return
        }

        dispatch()
    }
}

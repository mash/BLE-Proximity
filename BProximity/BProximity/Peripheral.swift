// Copyright (c) 2020- Masakazu Ohtsuka / maaash.jp
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
// OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import CoreBluetooth

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
        guard let discoveredServices = peripheral.services else { return }

        for discoveredService in discoveredServices {
            peripheral.discoverCharacteristics(nil, for: discoveredService)
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

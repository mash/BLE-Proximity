//
//  PeripheralManager.swift
//  BProximity
//
//  Created by Masakazu Ohtsuka on 2020/04/09.
//  Copyright © 2020 maaash.jp. All rights reserved.
//

import Foundation
import CoreBluetooth

typealias PeripheralManagerOnRead = (CBCentral, Characteristic)->(Data?)
typealias PeripheralManagerOnWrite = (CBCentral, Characteristic, Data)->(Bool)

class PeripheralManager :NSObject {
    private var started :Bool = false
    private let peripheralManager :CBPeripheralManager
    private var onRead :PeripheralManagerOnRead?
    private var onWrite :PeripheralManagerOnWrite?

    override init() {
        peripheralManager = CBPeripheralManager(delegate: nil, queue: nil)
        super.init()
        peripheralManager.delegate = self
    }

    func start() {
        started = true
        startAdvertising()
    }

    func stop() {
        started = false
        stopAdvertising()
    }

    private func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }

        // no pairing/bonding
        let read = CBMutableCharacteristic(type: Characteristic.ReadId.toCBUUID(), properties: .read, value: nil, permissions: .readable)
        let write = CBMutableCharacteristic(type: Characteristic.WriteId.toCBUUID(), properties: .writeWithoutResponse, value: nil, permissions: .writeable)
        let service = CBMutableService(type: Service.BProximity.toCBUUID(), primary: true)
        service.characteristics = [read, write]
        peripheralManager.add(service)

        let advertisementData = [
            CBAdvertisementDataServiceUUIDsKey: [Service.BProximity.toCBUUID()]
        ]
        peripheralManager.startAdvertising(advertisementData)
    }

    private func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }

    func onRead(callback :@escaping PeripheralManagerOnRead) -> PeripheralManager {
        onRead = callback
        return self
    }

    func onWrite(callback :@escaping PeripheralManagerOnWrite) -> PeripheralManager {
        onWrite = callback
        return self
    }
}

extension PeripheralManager :CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        log("state=\(peripheral.state)")
        if peripheral.state == .poweredOn && started {
            startAdvertising()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        log("dict=\(dict)")
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        log("error=\(String(describing: error))")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        log("request=\(request)")

        guard let ch = Characteristic.fromCBCharacteristic(request.characteristic), let onRead = onRead else {
            peripheralManager.respond(to: request, withResult: .requestNotSupported)
            return
        }
        if let data = onRead(request.central, ch) {
            request.value = data
            peripheral.respond(to: request, withResult: .success)
        }
        peripheralManager.respond(to: request, withResult: .unlikelyError)
    }

    // https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/1393315-peripheralmanager
    // When you respond to a write request, note that the first parameter of the respond(to:withResult:) method expects a single CBATTRequest object, even though you received an array of them from the peripheralManager(_:didReceiveWrite:) method. To respond properly, pass in the first request of the requests array.
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        log("requests=\(requests)")

        if (requests.count == 0) {
            return
        }

        var success = false
        requests.forEach { (request) in
            guard let ch = Characteristic.fromCBCharacteristic(request.characteristic), let onWrite = onWrite, let val = request.value else {
                return
            }
            if onWrite(request.central, ch, val) {
                success = true
            }
        }
        peripheralManager.respond(to: requests[0], withResult: success ? .success : .unlikelyError)
    }
}

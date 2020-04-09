//
//  BProximity.swift
//  BProximity
//
//  Created by Masakazu Ohtsuka on 2020/04/08.
//  Copyright © 2020 maaash.jp. All rights reserved.
//

import Foundation
import CoreBluetooth

enum Service :String {
    case BProximity = "8E99298E-65D6-4AF7-9074-731C66E01AF9" // from `uuidgen`
    func toCBUUID() -> CBUUID {
        return CBUUID(string: self.rawValue)
    }
}

enum Characteristic :String, CustomStringConvertible {
    case ReadId = "9F565547-7415-4EF7-8CDD-E2E9674EF033" // from `uuidgen`
    case WriteId = "B222EBFF-99B4-4BC4-A2E4-717AEF9966A6" // from `uuidgen`

    func toService() -> Service {
        switch self {
        case .ReadId:
            return .BProximity
        case .WriteId:
            return .BProximity
        }
    }
    func toCBUUID() -> CBUUID {
        return CBUUID(string: self.rawValue)
    }
    var description :String {
        switch self {
        case .ReadId:
            return "ReadId"
        case .WriteId:
            return "WriteId"
        }
    }
    static func fromCBCharacteristic(c :CBCharacteristic) -> Characteristic? {
        return Characteristic(rawValue: c.uuid.uuidString)
    }
}

typealias UserId = UInt64

extension UserId {
    func data() -> Data {
        return Swift.withUnsafeBytes(of: self) { Data($0) }
    }
    init?(data :Data) {
        var value :UserId = 0
        guard data.count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { data.copyBytes(to: $0)} )
        self = value
    }
}

public class BProximity :NSObject {
    static var instance :BProximity!

    private var peripheralManager :PeripheralManager!
    private var centralManager :CentralManager!
    private var started :Bool = false
    private var userIds :[UserId] = []
    private var peerIds :[UserId] = []

    public static func start() {
        log()
        instance = BProximity()
        instance.started = true
    }

    public static func stop() {
        log()
        instance.started = false
        instance.peripheralManager.stopAdvertising()
        instance.centralManager.stopScan()
    }

    public override init() {
        super.init()
        peripheralManager = PeripheralManager(delegate: self)
        centralManager = CentralManager(services: [Service.BProximity.toCBUUID()], delegate: self)
            .readValue(from: .ReadId)
            .writeValue(to: .WriteId, value: { [unowned self] in self.userId.data() })
            .didUpdateValue { [unowned self] (ch, value, error) in
                log("didUpdateValue ch=\(ch), value\(String(describing: value)), error=\(String(describing: error))")
                if let val = value, let userId = UserId(data: val) {
                    self.peerIds.append(userId)
                }
            }
        userIds = []
    }

    var userId :UserId {
        get {
            return userIds.first!
        }
    }
}

extension BProximity :PeripheralManagerDelegate {

}

extension BProximity :CentralManagerDelegate {

}

extension CBManagerState :CustomStringConvertible {
    public var description: String {
        switch self {
        case .poweredOff:
            return "poweredOff"
        case .poweredOn:
            return "poweredOn"
        case .resetting:
            return "resetting"
        case .unauthorized:
            return "unauthorized"
        case .unknown:
            return "unknown"
        case .unsupported:
            return "unsupported"
        @unknown default:
            return "@unknown"
        }
    }
}

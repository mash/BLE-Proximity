//
//  BProximity.swift
//  BProximity
//
//  Created by Masakazu Ohtsuka on 2020/04/08.
//  Copyright © 2020 maaash.jp. All rights reserved.
//

import Foundation
import CoreBluetooth
import UserNotifications

public enum Service :String {
    case BProximity = "8E99298E-65D6-4AF7-9074-731C66E01AF9" // from `uuidgen`
    public func toCBUUID() -> CBUUID {
        return CBUUID(string: self.rawValue)
    }
}

public enum Characteristic :String, CustomStringConvertible {
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
    public var description :String {
        switch self {
        case .ReadId:
            return "ReadId"
        case .WriteId:
            return "WriteId"
        }
    }
    static func fromCBCharacteristic(_ c :CBCharacteristic) -> Characteristic? {
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

    public static func didFinishLaunching() {
        log()
        instance = BProximity()
    }

    public static func start() {
        log()
        instance.peripheralManager.start()
        instance.centralManager.start()

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, error in
            log("granted: \(granted), error: \(String(describing: error))")
        }
    }

    public static func stop() {
        log()
        instance.peripheralManager.stop()
        instance.centralManager.stop()
    }

    public override init() {
        super.init()

        peripheralManager = PeripheralManager()
            .onRead { [unowned self] (peripheral, ch) in
                switch ch {
                case .ReadId:
                    return self.userId.data()
                case .WriteId:
                    return nil
                }
            }
            .onWrite { [unowned self] (peripheral, ch, data) in
                switch ch {
                case .ReadId:
                    return false
                case .WriteId:
                    if let userId = UserId(data: data) {
                        log("Written Successful by \(userId)")
                        self.peerIds.append(userId)
                        self.debugNotify(identifier: "Written", message: "Written Successful by \(userId)")
                        return true
                    }
                    log("data to UserId parse failed: \(data)")
                    return false
                }
            }
        centralManager = CentralManager(services: [Service.BProximity.toCBUUID()])
            .appendCommand(command: .Read(from: .ReadId, didUpdate: { [unowned self] (ch, value, error) in
                if let val = value, let userId = UserId(data: val) {
                    log("Read Successful from \(userId)")
                    self.peerIds.append(userId)
                    self.debugNotify(identifier: "Read", message: "Read Successful from \(userId)")
                }
            }))
            .appendCommand(command: .Write(to: .WriteId, value: { [unowned self] in self.userId.data() }))
            // TODO add a command to periodically read from the near peripheral
            // This will make CentralManager re-discover the same peripheral and re-scan the services and re-read and re-write and loop. Let's not do that
            // .appendCommand(command: .Cancel(callback: { [unowned self] peripheral in self.centralManager.disconnect(peripheral) }))
        userIds = [ randomUserId() ]
    }

    var userId :UserId {
        get {
            return userIds.first!
        }
    }

    func randomUserId() -> UserId {
        // https://github.com/apple/swift-evolution/blob/master/proposals/0202-random-unification.md#random-number-generator
        // This is cryptographically random
        return UInt64.random(in: 0 ... UInt64.max)
    }

    // TODO delete this
    func debugNotify(identifier :String, message :String) {
        let content = UNMutableNotificationContent()
        content.title = message
        let notification = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(notification) { (er) in
            if er != nil {
                log("notification error: \(er!)")
            }
        }
    }
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

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
import UserNotifications

enum Service :String {
    case BProximity = "8E99298E-65D6-4AF7-9074-731C66E01AF9" // from `uuidgen`
    public func toCBUUID() -> CBUUID {
        return CBUUID(string: self.rawValue)
    }
}

enum Characteristic :String, CustomStringConvertible {
    typealias DidUpdateValue = (Characteristic, Data?, Error?)->()

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

// We dropped 32bit support, so UInt = UInt64, and is converted to NSNumber when saving to PLists
typealias UserId = UInt

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
    static func next() -> UserId {
        // https://github.com/apple/swift-evolution/blob/master/proposals/0202-random-unification.md#random-number-generator
        // This is cryptographically random
        return UserId(UInt64.random(in: 0 ... UInt64.max))
    }
}

typealias Ids = [[UserId:TimeInterval]]

let KeepMyIdsInterval :TimeInterval = 60*60*24*7*4 // 4 weeks
let KeepPeerIdsInterval :TimeInterval = 60*60*24*7*4 // 4 weeks

enum File :String {
    case myIds
    case peerIds
    func url() -> URL {
        let documentDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectoryUrl.appendingPathComponent("\(self.rawValue).plist")
    }
}
extension Ids {
    // 8Byte + 8Bytes = 16Bytes for one record.
    // You're going to see .. max 1k people in a day.
    // We want to keep records for 4 weeks.
    // max: 16B x 1k x 28 = 448kBytes
    static func load(from :File) -> Ids {
        do {
            let data = try Data(contentsOf: from.url(), options: [])
            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! Ids
        } catch {
            log(error)
        }
        return Ids()
    }
    func save(to :File) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            try data.write(to: to.url(), options: [])
        } catch {
            log(error)
        }
    }
    mutating func expire(keepInterval: TimeInterval) -> Bool {
        let count = self.count

        // Delete old entries
        let now = Date().timeIntervalSince1970
        self = self.filter({ (item) -> Bool in
            let val = item.values.first!
            return val + keepInterval > now
        })

        // Return if we removed expired items
        return count != self.count
    }
    mutating func append(_ userId :UserId) {
        let next = [userId: Date().timeIntervalSince1970]
        self.append(next)
    }
    var last :UserId {
        let item = self.last! // at least one item should exist in the array
        return item.keys.first!
    }

    // TODO find
}

enum Command {
    case Read(from :Characteristic)
    case Write(to :Characteristic, value :()->(Data))
    case Cancel(callback :(Peripheral)->())
}

public class BProximity :NSObject {
    static var instance :BProximity!

    private var peripheralManager :PeripheralManager!
    private var centralManager :CentralManager!
    private var started :Bool = false
    private var myIds :Ids!
    private var peerIds :Ids!

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

        myIds = Ids.load(from: .myIds)
        _ = myIds.expire(keepInterval: KeepMyIdsInterval)
        myIds.append(UserId.next()) // TODO only when some time has passed
        myIds.save(to: .myIds)

        peerIds = Ids.load(from: .peerIds)
        if peerIds.expire(keepInterval: KeepPeerIdsInterval) {
            peerIds.save(to: .peerIds)
        }

        // no pairing/bonding
        let read = CBMutableCharacteristic(type: Characteristic.ReadId.toCBUUID(), properties: .read, value: nil, permissions: .readable)
        let write = CBMutableCharacteristic(type: Characteristic.WriteId.toCBUUID(), properties: .writeWithoutResponse, value: nil, permissions: .writeable)
        let service = CBMutableService(type: Service.BProximity.toCBUUID(), primary: true)
        service.characteristics = [read, write]

        peripheralManager = PeripheralManager(services: [service])
            .onRead { [unowned self] (peripheral, ch) in
                switch ch {
                case .ReadId:
                    return self.myIds.last.data()
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
                        self.peerIds.save(to: .peerIds)
                        self.debugNotify(identifier: "Written", message: "Written Successful by \(userId)")
                        return true
                    }
                    log("data to UserId parse failed: \(data)")
                    return false
                }
            }
        centralManager = CentralManager(services: [Service.BProximity.toCBUUID()])
            .didUpdateValue({ [unowned self] (ch, value, error) in
                if let val = value, let userId = UserId(data: val) {
                    log("Read Successful from \(userId)")
                    self.peerIds.append(userId)
                    self.peerIds.save(to: .peerIds)
                    self.debugNotify(identifier: "Read", message: "Read Successful from \(userId)")
                }
            })
            .appendCommand(command: .Read(from: .ReadId))
            .appendCommand(command: .Write(to: .WriteId, value: { [unowned self] in self.myIds.last.data() }))
            // This will make CentralManager re-discover the same peripheral and re-scan the services and re-read and re-write and loop. Let's not do that
            // .appendCommand(command: .Cancel(callback: { [unowned self] peripheral in self.centralManager.disconnect(peripheral) }))
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

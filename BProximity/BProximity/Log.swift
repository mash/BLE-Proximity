//
//  Log.swift
//  BeaconExample
//
//  Created by Masakazu Ohtsuka on 2020/04/08.
//  Copyright © 2020 maaash.jp. All rights reserved.
//

import Foundation

func log(_ vars :Any..., filename: String = #file, line: Int = #line, funcname: String = #function) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    dateFormatter.timeZone = NSTimeZone(abbreviation: "UTC") as TimeZone?
    let isMain = Thread.current.isMainThread
    let file = filename.components(separatedBy: "/").last ?? ""
    Swift.print("\(dateFormatter.string(from: Foundation.Date()))|Thread \(isMain ? "M" : "?")|\(file)#\(line) \(funcname)|" + vars.map { v in "\(v)" }.joined())
}

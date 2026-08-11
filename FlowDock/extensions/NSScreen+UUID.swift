//
//  NSScreen+UUID.swift
//  FlowDock
//
//  Created by Alexander on 2025-11-21.
//

import AppKit
import CoreGraphics

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    /// Returns a persistent UUID for this display
    var displayUUID: String? {
        guard let displayID else {
            return nil
        }
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return nil
        }
        let uuidString = CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
        return uuidString
    }
    
    static func screen(withUUID uuid: String) -> NSScreen? {
        return NSScreen.screens.first { $0.displayUUID == uuid }
    }
}

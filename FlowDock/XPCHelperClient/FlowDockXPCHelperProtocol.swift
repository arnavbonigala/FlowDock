//
//  FlowDockXPCHelperProtocol.swift
//  FlowDockXPCHelper
//
//  Created by Alexander on 2025-11-16.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc protocol FlowDockXPCHelperProtocol {
    func isAccessibilityAuthorized(with reply: @escaping (Bool) -> Void)
    func requestAccessibilityAuthorization()
    func ensureAccessibilityAuthorization(_ promptIfNeeded: Bool, with reply: @escaping (Bool) -> Void)
    // Keyboard backlight / CoreBrightness access (performed by the helper)
    func isKeyboardBrightnessAvailable(with reply: @escaping (Bool) -> Void)
    func currentKeyboardBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setKeyboardBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    // Screen brightness access (performed by the helper)
    func isScreenBrightnessAvailable(forDisplay displayID: UInt32, with reply: @escaping (Bool) -> Void)
    func currentScreenBrightness(forDisplay displayID: UInt32, with reply: @escaping (NSNumber?) -> Void)
    func setScreenBrightness(_ value: Float, forDisplay displayID: UInt32, with reply: @escaping (Bool) -> Void)
    func startNotificationRelay()
    func stopNotificationRelay()
    func performNotificationAction(_ action: String, token: String)
}

@objc protocol FlowDockXPCHelperClientProtocol {
    func notificationsChanged(_ json: String)
}

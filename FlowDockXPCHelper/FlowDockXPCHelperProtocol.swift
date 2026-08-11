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

/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     connectionToService = NSXPCConnection(serviceName: "com.arnavbonigala.flowdock.FlowDockXPCHelper")
     connectionToService.remoteObjectInterface = NSXPCInterface(with: (any FlowDockXPCHelperProtocol).self)
     connectionToService.resume()

 Once you have a connection to the service, you can use it like this:

     if let proxy = connectionToService.remoteObjectProxy as? FlowDockXPCHelperProtocol {
         proxy.performCalculation(firstNumber: 23, secondNumber: 19) { result in
             NSLog("Result of calculation is: \(result)")
         }
     }

 And, when you are finished with the service, clean up the connection like this:

     connectionToService.invalidate()
*/

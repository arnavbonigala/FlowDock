//
//  DeviceMonitor.swift
//  FlowDock
//

import Combine
import Defaults
import Foundation
import IOBluetooth
import IOKit

struct ConnectedDevice: Identifiable, Equatable {
    let address: String
    let name: String
    let symbol: String
    let batteryPercent: Int?
    let isConnected: Bool

    var id: String { address }

    var status: String {
        isConnected ? "Connected" : "Disconnected"
    }

    var label: String {
        var parts = ["\(name), \(status.lowercased())"]
        if let batteryPercent { parts.append("\(batteryPercent) percent battery") }
        return parts.joined(separator: ", ")
    }

    static func symbol(major: UInt32, minor: UInt32) -> String {
        switch (major, minor) {
        case (UInt32(kBluetoothDeviceClassMajorAudio), UInt32(kBluetoothDeviceClassMinorAudioHeadphones)),
             (UInt32(kBluetoothDeviceClassMajorAudio), UInt32(kBluetoothDeviceClassMinorAudioHeadset)):
            return "headphones"
        case (UInt32(kBluetoothDeviceClassMajorAudio), _):
            return "hifispeaker.fill"
        case (UInt32(kBluetoothDeviceClassMajorPeripheral), UInt32(kBluetoothDeviceClassMinorPeripheral1Keyboard)):
            return "keyboard.fill"
        case (UInt32(kBluetoothDeviceClassMajorPeripheral), UInt32(kBluetoothDeviceClassMinorPeripheral1Pointing)):
            return "computermouse.fill"
        case (UInt32(kBluetoothDeviceClassMajorPhone), _):
            return "iphone"
        default:
            return "dot.radiowaves.right"
        }
    }
}

@MainActor
final class DeviceMonitor: NSObject, ObservableObject {
    static let shared = DeviceMonitor()

    @Published private(set) var devices: [ConnectedDevice] = []
    @Published private(set) var lastChange: ConnectedDevice?

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var running = false

    private override init() {
        super.init()
    }

    func start() {
        guard !running else { return }
        running = true
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
        for device in connectedBluetoothDevices() {
            watchDisconnect(device)
        }
        refresh()
    }

    func stop() {
        guard running else { return }
        running = false
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications.removeAll()
        devices = []
        lastChange = nil
    }

    func refresh() {
        let batteries = batteryLevels()
        devices = connectedBluetoothDevices().map { device in
            ConnectedDevice(
                address: device.addressString ?? "",
                name: device.name ?? "Device",
                symbol: ConnectedDevice.symbol(major: device.deviceClassMajor, minor: device.deviceClassMinor),
                batteryPercent: batteries[device.name ?? ""],
                isConnected: true
            )
        }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        watchDisconnect(device)
        refresh()
        announce(device, connected: true)
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        if let address = device.addressString { disconnectNotifications[address] = nil }
        refresh()
        announce(device, connected: false)
    }

    private func watchDisconnect(_ device: IOBluetoothDevice) {
        guard let address = device.addressString, disconnectNotifications[address] == nil else { return }
        disconnectNotifications[address] = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:))
        )
    }

    private func announce(_ device: IOBluetoothDevice, connected: Bool) {
        let address = device.addressString ?? ""
        if connected, let known = devices.first(where: { $0.address == address }) {
            lastChange = known
            return
        }
        lastChange = ConnectedDevice(
            address: address,
            name: device.name ?? "Device",
            symbol: ConnectedDevice.symbol(major: device.deviceClassMajor, minor: device.deviceClassMinor),
            batteryPercent: nil,
            isConnected: connected
        )
    }

    private func connectedBluetoothDevices() -> [IOBluetoothDevice] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).filter { $0.isConnected() }
    }

    private func batteryLevels() -> [String: Int] {
        var levels: [String: Int] = [:]
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleDeviceManagementHIDEventService"),
            &iterator
        ) == KERN_SUCCESS else { return levels }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let properties = unmanaged?.takeRetainedValue() as? [String: Any],
                  let name = properties["Product"] as? String,
                  let percent = properties["BatteryPercent"] as? Int
            else { continue }
            levels[name] = percent
        }
        return levels
    }
}

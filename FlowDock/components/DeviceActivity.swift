//
//  DeviceActivity.swift
//  FlowDock
//

import Defaults
import IOBluetooth
import SwiftUI

extension Activity {
    static let deviceID = "device"
    static let deviceChinSide: CGFloat = 34

    static func device(_ device: ConnectedDevice) -> Activity {
        Activity(
            id: deviceID,
            activityClass: .contextual,
            band: .power,
            label: device.label,
            chinSideWidth: deviceChinSide,
            leading: {
                Image(systemName: device.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(device.isConnected ? .white : .secondary)
                    .frame(width: deviceChinSide, alignment: .leading)
            },
            trailing: {
                Group {
                    if let percent = device.batteryPercent {
                        Text("\(percent)%")
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: device.isConnected ? "checkmark" : "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: deviceChinSide, alignment: .trailing)
            }
        )
    }
}

extension View {
    func deviceActivity(in store: ActivityStore) -> some View {
        modifier(DeviceActivityBinder(store: store))
    }
}

private struct DeviceActivityBinder: ViewModifier {
    let store: ActivityStore

    @ObservedObject private var monitor = DeviceMonitor.shared
    @Default(.showDeviceStatus) private var enabled

    func body(content: Content) -> some View {
        content
            .onChange(of: monitor.lastChange) { _, change in
                guard enabled, let change else { return }
                store.begin(.device(change))
            }
            .onChange(of: enabled, initial: true) { _, enabled in
                if enabled {
                    monitor.start()
                } else {
                    monitor.stop()
                    store.end(Activity.deviceID)
                }
            }
    }
}

struct DevicePanel: View {
    @ObservedObject private var monitor = DeviceMonitor.shared
    @Default(.showDeviceStatus) private var enabled

    var body: some View {
        if enabled, !monitor.devices.isEmpty {
            HStack(spacing: 10) {
                ForEach(monitor.devices) { device in
                    HStack(spacing: 4) {
                        Image(systemName: device.symbol)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        if let percent = device.batteryPercent {
                            Text("\(percent)%")
                                .font(.system(size: 11, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(device.label)
                }
            }
            .onAppear { monitor.refresh() }
        }
    }
}

#if DEBUG
extension DevicePanel {
    static func selfCheck() {
        let airpods = ConnectedDevice(
            address: "00-11", name: "AirPods", symbol: "headphones", batteryPercent: 72, isConnected: true
        )
        assert(airpods.label == "AirPods, connected, 72 percent battery")
        assert(ConnectedDevice(address: "00-11", name: "Trackpad", symbol: "", batteryPercent: nil, isConnected: false)
            .label == "Trackpad, disconnected")
        assert(ConnectedDevice.symbol(
            major: UInt32(kBluetoothDeviceClassMajorAudio),
            minor: UInt32(kBluetoothDeviceClassMinorAudioHeadphones)
        ) == "headphones")
        assert(ConnectedDevice.symbol(
            major: UInt32(kBluetoothDeviceClassMajorPeripheral),
            minor: UInt32(kBluetoothDeviceClassMinorPeripheral1Keyboard)
        ) == "keyboard.fill")
        assert(ConnectedDevice.symbol(major: 99, minor: 99) == "dot.radiowaves.right")
        assert(Activity.device(airpods).activityClass == .contextual)
        assert(Activity.device(airpods).band == .power)
    }
}
#endif

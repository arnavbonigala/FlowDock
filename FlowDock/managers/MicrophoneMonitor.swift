//
//  MicrophoneMonitor.swift
//  FlowDock
//

import CoreAudio
import Combine
import Defaults
import SwiftUI

final class MicrophoneMonitor: NSObject, ObservableObject {
    static let shared = MicrophoneMonitor()

    @Published private(set) var inUse = false
    @Published private(set) var isMuted = false
    @Published private(set) var since: Date?
    @Published private(set) var listener: String?
    @Published private(set) var listenerBundleID: String?

    private let listenerQueue = DispatchQueue(label: "com.arnavbonigala.flowdock.microphone-listeners")
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var running = false
    private var volumeBeforeMute: Float32 = 1
    private var softwareMuted = false

    private override init() {}

    func start() {
        guard !running else { return }
        running = true
        observe(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice, .global)
        observe(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList, .global)
        attachDeviceListeners()
        refresh()
    }

    /// A device muted through its mute switch says so in Sound settings, so leaving it
    /// muted is honest. One turned down to nothing does not, and a microphone stuck at
    /// zero with nothing on screen explaining it reads as broken hardware.
    func stop() {
        guard running else { return }
        running = false
        if softwareMuted { toggleMute() }
        detach()
        inUse = false
    }

    // MARK: - Mute

    /// Muting the input device silences the microphone for every application at once,
    /// which is the point: the conferencing app's own button only speaks for itself.
    /// A device that will not mute is turned down to nothing and put back afterwards.
    func toggleMute() {
        let device = inputDevice()
        guard device != kAudioObjectUnknown else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(device, &address), settable(device, &address) {
            var value: UInt32 = isMuted ? 0 : 1
            let status = AudioObjectSetPropertyData(
                device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
            if status != noErr {
                NSLog("Could not mute the microphone: status \(status)")
                return
            }
        } else {
            var volume = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectHasProperty(device, &volume), settable(device, &volume) else { return }
            if !isMuted { volumeBeforeMute = inputVolume(device) ?? 1 }
            var target: Float32 = isMuted ? volumeBeforeMute : 0
            let status = AudioObjectSetPropertyData(
                device, &volume, 0, nil, UInt32(MemoryLayout<Float32>.size), &target)
            if status != noErr {
                NSLog("Could not turn the microphone down: status \(status)")
                return
            }
            softwareMuted = !isMuted
        }

        refresh()
    }

    // MARK: - Reading

    func refresh() {
        let device = inputDevice()
        guard device != kAudioObjectUnknown else {
            publish(inUse: false, muted: false, bundleID: nil)
            return
        }
        let running = isRunningSomewhere(device)
        publish(inUse: running, muted: readMuted(device), bundleID: running ? listeningApp() : nil)
    }

    private func publish(inUse: Bool, muted: Bool, bundleID: String?) {
        DispatchQueue.main.async {
            if self.inUse != inUse {
                self.inUse = inUse
                self.since = inUse ? Date() : nil
            }
            if self.isMuted != muted { self.isMuted = muted }
            if self.listenerBundleID != bundleID {
                self.listenerBundleID = bundleID
                self.listener = bundleID.flatMap(Self.displayName)
            }
        }
    }

    private static func displayName(of bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path)
    }

    /// macOS reports every process that has audio running, so the one holding the
    /// microphone can be named without asking for a permission. Before 14.4 there is no
    /// such list and the activity simply says less.
    private func listeningApp() -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectHasProperty(system, &address) else { return nil }

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0
        else { return nil }

        var processes = [AudioObjectID](
            repeating: kAudioObjectUnknown, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr
        else { return nil }

        let own = Bundle.main.bundleIdentifier
        for process in processes where isRunningInput(process) {
            guard let bundleID = bundleID(of: process), bundleID != own else { continue }
            return bundleID
        }
        return nil
    }

    private func isRunningInput(_ process: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningInput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(process, &address) else { return false }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &running) == noErr
        else { return false }
        return running != 0
    }

    private func bundleID(of process: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(process, &address) else { return nil }
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &value) == noErr,
              let bundleID = value?.takeRetainedValue() as String?,
              !bundleID.isEmpty
        else { return nil }
        return bundleID
    }

    private func inputDevice() -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr
        else { return kAudioObjectUnknown }
        return device
    }

    private func isRunningSomewhere(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return false }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr
        else { return false }
        return running != 0
    }

    private func readMuted(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(device, &address) {
            var muted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr {
                return muted != 0
            }
        }
        return (inputVolume(device) ?? 1) == 0
    }

    private func inputVolume(_ device: AudioObjectID) -> Float32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr
        else { return nil }
        return value
    }

    private func settable(_ device: AudioObjectID, _ address: inout AudioObjectPropertyAddress) -> Bool {
        var value: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &value) == noErr else { return false }
        return value.boolValue
    }

    // MARK: - Listeners

    private func attachDeviceListeners() {
        let device = inputDevice()
        guard device != kAudioObjectUnknown else { return }
        observe(device, kAudioDevicePropertyDeviceIsRunningSomewhere, .global)
        observe(device, kAudioDevicePropertyMute, .input)
        observe(device, kAudioDevicePropertyVolumeScalar, .input)
    }

    private enum Scope {
        case global, input

        var selector: AudioObjectPropertyScope {
            self == .global ? kAudioObjectPropertyScopeGlobal : kAudioDevicePropertyScopeInput
        }
    }

    private func observe(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: Scope) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope.selector,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(object, &address) else { return }

        let isDefaultDevice = selector == kAudioHardwarePropertyDefaultInputDevice
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            if isDefaultDevice {
                self.detachDeviceListeners()
                self.attachDeviceListeners()
            }
            self.refresh()
        }
        guard AudioObjectAddPropertyListenerBlock(object, &address, listenerQueue, block) == noErr
        else { return }
        listeners.append((object, address, block))
    }

    private func detachDeviceListeners() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        for (object, address, block) in listeners where object != system {
            var address = address
            AudioObjectRemovePropertyListenerBlock(object, &address, listenerQueue, block)
        }
        listeners.removeAll { $0.0 != system }
    }

    private func detach() {
        for (object, address, block) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(object, &address, listenerQueue, block)
        }
        listeners.removeAll()
    }
}

extension Activity {
    static let microphoneID = "microphone"

    static func microphone(muted: Bool, since: Date?, app: String?) -> Activity {
        Activity(
            id: microphoneID,
            activityClass: .persistent,
            band: .media,
            label: MicrophonePanel.label(muted: muted, app: app),
            chinSideWidth: Activity.chinClockSide,
            leading: {
                Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                    .font(.chinGlyph)
                    .foregroundStyle(muted ? Color.red : .primary)
                    .frame(width: Activity.chinClockSide, alignment: .leading)
            },
            trailing: {
                Group {
                    if let since {
                        ElapsedText(since: since)
                    } else {
                        Text(muted ? "Muted" : "Live")
                            .font(.chinValue)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: Activity.chinClockSide, alignment: .trailing)
            }
        )
        .withExpanded { MicrophonePanel() }
    }
}

extension View {
    func microphoneActivity(in store: ActivityStore) -> some View {
        modifier(MicrophoneActivityBinder(store: store))
    }
}

private struct MicrophoneActivityBinder: ViewModifier {
    let store: ActivityStore

    @ObservedObject private var monitor = MicrophoneMonitor.shared
    @Default(.showMicrophoneActivity) private var enabled

    private struct Trigger: Equatable {
        var inUse: Bool
        var muted: Bool
        var since: Date?
        var app: String?
    }

    private var trigger: Trigger {
        Trigger(inUse: monitor.inUse, muted: monitor.isMuted, since: monitor.since, app: monitor.listener)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, state in
                guard enabled else { return }
                if state.inUse {
                    store.begin(.microphone(muted: state.muted, since: state.since, app: state.app))
                } else {
                    store.end(Activity.microphoneID)
                }
            }
            .onChange(of: enabled, initial: true) { _, enabled in
                if enabled {
                    monitor.start()
                } else {
                    monitor.stop()
                    store.end(Activity.microphoneID)
                }
            }
    }
}

/// SwiftUI drives a timer interval itself, so the elapsed time on the chin costs no
/// timer of FlowDock's own. See QUALITY.md on work that runs when nothing is happening.
struct ElapsedText: View {
    let since: Date

    var body: some View {
        Text(timerInterval: since...Date.distantFuture, countsDown: false)
            .font(.chinValue)
            .monospacedDigit()
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
}

struct MicrophonePanel: View {
    @ObservedObject private var monitor = MicrophoneMonitor.shared

    static func label(muted: Bool, app: String?) -> String {
        let who = app.map { "\($0) is using the microphone" } ?? "Microphone in use"
        return muted ? "\(who), muted" : who
    }

    var body: some View {
        HStack(spacing: 12) {
            if let bundleID = monitor.listenerBundleID {
                AppIcon(for: bundleID)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: monitor.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.panelPrimary)
                    .foregroundStyle(monitor.isMuted ? Color.red : .primary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.listener ?? (monitor.isMuted ? "Microphone muted" : "Microphone in use"))
                    .font(.panelPrimary)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let since = monitor.since {
                        Text(timerInterval: since...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                        Text("·")
                    }
                    Text(monitor.isMuted ? "Muted everywhere" : "Live in every app")
                }
                .font(.panelMeta)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                monitor.toggleMute()
            } label: {
                Text(monitor.isMuted ? "Unmute" : "Mute")
                    .font(.panelControl)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(.quaternary, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }
}

//
//  KeepAwake.swift
//  FlowDock
//

import IOKit.pwr_mgt
import SwiftUI

@MainActor
final class KeepAwake: ObservableObject {
    static let shared = KeepAwake()

    @Published private(set) var isOn = false

    private var assertion: IOPMAssertionID = 0

    private init() {}

    func toggle() {
        isOn ? stop() : start()
    }

    private func start() {
        var id: IOPMAssertionID = 0
        let created = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "FlowDock is keeping the display awake" as CFString,
            &id
        )
        guard created == kIOReturnSuccess else { return }
        assertion = id
        isOn = true
    }

    private func stop() {
        guard isOn else { return }
        IOPMAssertionRelease(assertion)
        assertion = 0
        isOn = false
    }
}

struct KeepAwakeButton: View {
    @ObservedObject private var keepAwake = KeepAwake.shared

    var body: some View {
        HoverButton(
            icon: keepAwake.isOn ? "cup.and.saucer.fill" : "cup.and.saucer",
            iconColor: keepAwake.isOn ? .effectiveAccent : .secondary,
            scale: .small
        ) {
            keepAwake.toggle()
        }
        .accessibilityLabel(keepAwake.isOn ? "Let the display sleep" : "Keep the display awake")
        .help(keepAwake.isOn ? "Let the display sleep" : "Keep the display awake")
    }
}

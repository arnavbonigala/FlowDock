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

extension Activity {
    static let keepAwakeID = "keepAwake"

    static func keepAwake() -> Activity {
        Activity(
            id: keepAwakeID,
            activityClass: .persistent,
            band: .ambient,
            label: "Display kept awake",
            chinSideWidth: 34,
            leading: {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.chinGlyph)
                    .foregroundStyle(.white)
                    .frame(width: 34, alignment: .leading)
            },
            trailing: {
                Text("Awake")
                    .font(.chinValue)
                    .foregroundStyle(.white)
                    .frame(width: 34, alignment: .trailing)
            }
        )
    }
}

extension View {
    func keepAwakeActivity(in store: ActivityStore) -> some View {
        modifier(KeepAwakeActivityBinder(store: store))
    }
}

private struct KeepAwakeActivityBinder: ViewModifier {
    let store: ActivityStore

    @ObservedObject private var keepAwake = KeepAwake.shared

    func body(content: Content) -> some View {
        content.onChange(of: keepAwake.isOn, initial: true) { _, on in
            if on {
                store.begin(.keepAwake())
            } else {
                store.end(Activity.keepAwakeID)
            }
        }
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
        .iconLabel(keepAwake.isOn ? "Let the display sleep" : "Keep the display awake")
    }
}

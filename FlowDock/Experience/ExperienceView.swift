//
//  ExperienceView.swift
//  FlowDock
//
//  The shell: it draws whichever state the store is in, and owns every input that
//  moves between states. Activities supply content and nothing else.
//  See DESIGN.md and INTERACTION.md.
//

import Defaults
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

extension Defaults.Keys {
    /// ponytail: debug switch, read once when the window is built. Relaunch to change it.
    /// Deleted along with `FlowDock/Experience/` when the last capability is ported.
    static let useNewExperience = Key<Bool>("useNewExperience", default: false)
}

/// Chooses between the inherited interface and the new shell.
struct ExperienceRootView: View {
    var body: some View {
        if Defaults[.useNewExperience] {
            ExperienceView()
        } else {
            ContentView()
        }
    }
}

struct ExperienceView: View {
    @EnvironmentObject var vm: FlowDockViewModel
    @StateObject private var store = ActivityStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hoverTask: Task<Void, Never>?
    @State private var isDropTargeted = false

    private var anchor: CGSize { getClosedNotchSize(screenUUID: vm.screenUUID) }

    private var displayHasNotch: Bool {
        let screen = vm.screenUUID.flatMap { NSScreen.screen(withUUID: $0) } ?? NSScreen.main
        return (screen?.safeAreaInsets.top ?? 0) > 0
    }

    var body: some View {
        let state = store.state

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Color.black
                content(for: state)
            }
                .frame(
                    width: state == .expanded ? openNotchSize.width : anchor.width,
                    height: state == .expanded ? openNotchSize.height : vm.effectiveClosedNotchHeight,
                    alignment: .top
                )
                .clipShape(
                    NotchShape(
                        topCornerRadius: displayHasNotch
                            ? (state == .expanded ? cornerRadiusInsets.opened.top : cornerRadiusInsets.closed.top)
                            : 0,
                        bottomCornerRadius: state == .expanded
                            ? cornerRadiusInsets.opened.bottom
                            : cornerRadiusInsets.closed.bottom
                    )
                )
                .contentShape(Rectangle())
                .task {
                    KeyboardShortcuts.disable(.dismissExpanded)
                    KeyboardShortcuts.onKeyDown(for: .dismissExpanded) { collapse() }
                }
                .onChange(of: store.isExpanded) { _, expanded in
                    // The panel cannot take key focus, so Escape is a hotkey that exists
                    // only while there is something to dismiss.
                    if expanded {
                        KeyboardShortcuts.enable(.dismissExpanded)
                    } else {
                        KeyboardShortcuts.disable(.dismissExpanded)
                    }
                }
                .onHover(perform: hover)
                .onTapGesture { expand() }
                .panGesture(direction: .down) { translation, _ in
                    if translation > Defaults[.gestureSensitivity] { expand() }
                }
                .panGesture(direction: .up) { translation, _ in
                    if translation > Defaults[.gestureSensitivity] { collapse() }
                }
                .onDrop(of: [.fileURL, .url, .plainText], isTargeted: $isDropTargeted) { _ in
                    false
                }
                .onChange(of: isDropTargeted) { _, targeted in
                    if targeted { expand() }
                }
                .contextMenu {
                    Button("Settings") { SettingsWindowController.shared.showWindow() }
                        .keyboardShortcut(",", modifiers: .command)
                }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .animation(.experience(reduceMotion: reduceMotion, collapsing: state != .expanded), value: state)
        .preferredColorScheme(.dark)
    }

    // MARK: - Surfaces

    @ViewBuilder
    private func content(for state: ActivityState) -> some View {
        switch state {
        case .idle:
            Color.clear
                .accessibilityHidden(true)

        case .contextual, .persistent:
            chin
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(store.owner?.label ?? "")
                .transition(.fromNotch(reduceMotion: reduceMotion))

        case .expanded:
            expandedPanel
                .transition(.fromNotch(reduceMotion: reduceMotion))
        }
    }

    private var chin: some View {
        HStack(spacing: 0) {
            store.owner?.leading()
            Color.clear.frame(width: anchor.width)
            store.owner?.trailing()
        }
        .padding(.horizontal, 8)
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let contextual = store.activities.first(where: { $0.activityClass == .contextual }) {
                HStack(spacing: 4) {
                    contextual.leading()
                    contextual.trailing()
                }
                .frame(height: max(24, vm.effectiveClosedNotchHeight))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(contextual.label)
            }

            ForEach(store.activities.filter { $0.activityClass == .persistent && $0.expanded != nil }) { activity in
                activity.expanded?()
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    // MARK: - Input

    private func hover(_ inside: Bool) {
        hoverTask?.cancel()

        guard inside else {
            hoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                collapse()
            }
            return
        }

        guard !store.isExpanded, store.state != .contextual, Defaults[.openNotchOnHover] else { return }

        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
            guard !Task.isCancelled else { return }
            expand()
        }
    }

    private func expand() {
        guard !store.isExpanded else { return }
        store.isExpanded = true
    }

    private func collapse() {
        guard store.isExpanded, !SharingStateManager.shared.preventNotchClose else { return }
        store.isExpanded = false
    }
}

#if DEBUG
#Preview {
    ExperienceView()
        .environmentObject(FlowDockViewModel())
        .frame(width: windowSize.width, height: windowSize.height)
}
#endif

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
    @State private var isOverAgenda = false

    @ObservedObject private var calendar = CalendarManager.shared
    @Default(.showCalendar) private var showCalendar

    static let contextColumn: CGFloat = 215

    private var showsAgenda: Bool { showCalendar }

    private var anchor: CGSize { getClosedNotchSize(screenUUID: vm.screenUUID) }

    /// `safeAreaInsets.top` stops at the notch, one point short of the menu bar, so a
    /// sliver of wallpaper shows under the surface. Reach the menu bar instead.
    private var closedHeight: CGFloat {
        guard let screen else { return vm.effectiveClosedNotchHeight }
        return max(vm.effectiveClosedNotchHeight, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    private func width(for state: ActivityState) -> CGFloat {
        switch state {
        case .expanded: openNotchSize.width
        case .idle: anchor.width
        case .contextual, .persistent:
            anchor.width + 2 * chinSide + 2 * chinInset
        }
    }

    private var chinSide: CGFloat {
        store.owner?.chinSideWidth ?? max(0, vm.effectiveClosedNotchHeight - 12)
    }

    private var chinInset: CGFloat {
        (displayHasNotch ? cornerRadiusInsets.closed.top : 0) + 8
    }

    private var panelInset: CGFloat {
        (displayHasNotch ? cornerRadiusInsets.opened.top : 0) + 24
    }

    private var screen: NSScreen? {
        vm.screenUUID.flatMap { NSScreen.screen(withUUID: $0) } ?? NSScreen.main
    }

    private var displayHasNotch: Bool {
        (screen?.safeAreaInsets.top ?? 0) > 0
    }

    var body: some View {
        let state = store.state

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Color.black
                content(for: state)
            }
                .frame(
                    width: width(for: state),
                    height: state == .expanded ? openNotchSize.height : closedHeight,
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
                    guard !isOverAgenda else { return }
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
        .musicActivity(in: store, suppressed: vm.hideOnClosed)
        .powerActivity(in: store)
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
        .padding(.horizontal, chinInset)
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let contextual = store.activities.first(where: { $0.activityClass == .contextual }) {
                    HStack(spacing: 4) {
                        contextual.leading()
                        contextual.trailing()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(contextual.label)
                }

                Spacer(minLength: 0)

                PowerPanelIndicator()
            }
            .frame(height: max(24, vm.effectiveClosedNotchHeight))

            HStack(alignment: .top, spacing: spacing) {
                VStack(alignment: .leading, spacing: 12) {
                    MusicPanel()

                    ForEach(store.activities.filter { $0.activityClass == .persistent && $0.expanded != nil }) { activity in
                        activity.expanded?()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if showsAgenda {
                    AgendaPanel()
                        .frame(width: Self.contextColumn)
                        .onHover { isOverAgenda = $0 }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, panelInset)
        .padding(.bottom, 12)
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

    /// The store owns the shell's state; the view model still holds the one notion of
    /// "the notch is open" that surfaces outside the shell — the system feedback pill —
    /// position themselves against.
    private func expand() {
        guard !store.isExpanded else { return }
        store.isExpanded = true
        vm.open()
    }

    private func collapse() {
        guard store.isExpanded, !SharingStateManager.shared.preventNotchClose else { return }
        isOverAgenda = false
        store.isExpanded = false
        vm.close()
    }
}

#if DEBUG
#Preview {
    ExperienceView()
        .environmentObject(FlowDockViewModel())
        .frame(width: windowSize.width, height: windowSize.height)
}
#endif

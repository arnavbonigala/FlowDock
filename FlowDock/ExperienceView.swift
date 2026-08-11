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

struct ExperienceView: View {
    @EnvironmentObject var vm: FlowDockViewModel
    @StateObject private var store = ActivityStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hoverTask: Task<Void, Never>?
    @State private var settleTask: Task<Void, Never>?
    @State private var isDropTargeted = false
    @State private var isOverAgenda = false
    @State private var haptics = false

    @ObservedObject private var calendar = CalendarManager.shared
    @ObservedObject private var drag = DragWatch.shared
    @Default(.showCalendar) private var showCalendar
    @Default(.shelfEnabled) private var shelfEnabled

    static let contextColumn: CGFloat = 215
    static let droppedTypes: [UTType] = [.fileURL, .url, .utf8PlainText, .plainText, .data]
    static let expandedShortcuts: [KeyboardShortcuts.Name] = [
        .dismissExpanded, .shelfSelectAll, .shelfCopySelection, .shelfRemoveSelected, .shelfClear,
    ]

    private var showsAgenda: Bool { showCalendar }

    private var anchor: CGSize { getClosedNotchSize(screenUUID: vm.screenUUID) }

    /// `safeAreaInsets.top` stops at the notch, one point short of the menu bar, so a
    /// sliver of wallpaper shows under the surface. Reach the menu bar instead.
    private var closedHeight: CGFloat {
        guard let screen else { return vm.effectiveClosedNotchHeight }
        return max(vm.effectiveClosedNotchHeight, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    private var panelSize: CGSize {
        guard let screen else { return openNotchSize }
        return CGSize(
            width: min(openNotchSize.width, screen.frame.width),
            height: min(openNotchSize.height, screen.frame.height - surfaceTopInset(screen))
        )
    }

    private func width(for state: ActivityState) -> CGFloat {
        switch state {
        case .expanded: panelSize.width
        case .idle: min(anchor.width, panelSize.width)
        case .contextual, .persistent:
            min(anchor.width + 2 * chinSide + 2 * chinInset, panelSize.width)
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

    private var isExpanded: Bool { vm.notchState == .open }

    var body: some View {
        let state: ActivityState = isExpanded ? .expanded : store.chinState

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Color.black
                content(for: state)
            }
                .frame(
                    width: width(for: state),
                    height: state == .expanded ? panelSize.height : closedHeight,
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
                .shadow(
                    color: Defaults[.enableShadow] && state != .idle ? .black.opacity(0.7) : .clear,
                    radius: 6
                )
                .contentShape(Rectangle())
                .sensoryFeedback(.alignment, trigger: haptics)
                .task {
                    Self.expandedShortcuts.forEach { KeyboardShortcuts.disable($0) }
                    KeyboardShortcuts.onKeyDown(for: .dismissExpanded) { collapse() }
                    KeyboardShortcuts.onKeyDown(for: .shelfSelectAll) { ShelfActionService.selectAll() }
                    KeyboardShortcuts.onKeyDown(for: .shelfCopySelection) { ShelfActionService.copySelection() }
                    KeyboardShortcuts.onKeyDown(for: .shelfRemoveSelected) { ShelfActionService.removeSelected() }
                    KeyboardShortcuts.onKeyDown(for: .shelfClear) { ShelfActionService.clearShelf() }
                }
                .onChange(of: isExpanded) { _, expanded in
                    // The panel cannot take key focus, so Escape is a hotkey that exists
                    // only while there is something to dismiss.
                    if expanded {
                        Self.expandedShortcuts.forEach { KeyboardShortcuts.enable($0) }
                    } else {
                        Self.expandedShortcuts.forEach { KeyboardShortcuts.disable($0) }
                    }
                }
                .onHover(perform: hover)
                .onTapGesture { expand() }
                .conditionalModifier(Defaults[.enableGestures]) { view in
                    view.panGesture(direction: .down) { translation, _ in
                        if translation > Defaults[.gestureSensitivity] { expand() }
                    }
                }
                .conditionalModifier(Defaults[.enableGestures] && Defaults[.closeGestureEnabled]) { view in
                    view.panGesture(direction: .up) { translation, _ in
                        guard !isOverAgenda else { return }
                        if translation > Defaults[.gestureSensitivity] { collapse() }
                    }
                }
                .onDrop(
                    of: Self.droppedTypes,
                    isTargeted: $isDropTargeted
                ) { providers in accept(providers) }
                .onChange(of: isDropTargeted) { _, targeted in
                    guard shelfEnabled else { return }
                    if targeted {
                        settleTask?.cancel()
                        expand()
                    } else {
                        settle()
                    }
                }
                .contextMenu {
                    Button("Settings") { SettingsWindowController.shared.showWindow() }
                        .keyboardShortcut(",", modifiers: .command)
                }

            Spacer(minLength: 0)
        }
        .background(alignment: .top) { catcher }
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .animation(.experience(reduceMotion: reduceMotion, collapsing: state != .expanded), value: state)
        .preferredColorScheme(.dark)
        .musicActivity(in: store, suppressed: vm.hideOnClosed)
        .powerActivity(in: store, suppressed: isExpanded)
        .shelfActivity(in: store, receiving: isDropTargeted)
        .notificationActivity(in: store)
        .deviceActivity(in: store)
        .progressActivity(in: store)
        .countdownActivity(in: store)
        .extensionActivities(in: store)
    }

    /// Aiming at the cutout mid-drag is slow, so the whole top of the screen accepts the
    /// drop — but only while something is being dragged, or it would swallow menu bar clicks.
    @ViewBuilder
    private var catcher: some View {
        if shelfEnabled, !isExpanded, drag.dragging {
            Color.clear
                .frame(height: max(closedHeight, 24))
                .contentShape(Rectangle())
                .onDrop(of: Self.droppedTypes, isTargeted: $isDropTargeted) { providers in
                    accept(providers)
                }
        }
    }

    private func accept(_ providers: [NSItemProvider]) -> Bool {
        guard shelfEnabled else { return false }
        ShelfStateViewModel.shared.load(providers)
        settle()
        return true
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

                DevicePanel()

                PowerPanelIndicator()
            }
            .frame(height: max(24, vm.effectiveClosedNotchHeight))

            HStack(alignment: .top, spacing: spacing) {
                VStack(alignment: .leading, spacing: 8) {
                    MusicPanel()

                    ForEach(store.activities.filter { $0.activityClass == .persistent && $0.expanded != nil }) { activity in
                        activity.expanded?()
                    }

                    NotificationPanel()

                    TimerPanel()

                    if shelfEnabled {
                        ShelfPanel(targeted: isDropTargeted)
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

        settleTask?.cancel()

        if !isExpanded, Defaults[.enableHaptics] { haptics.toggle() }

        guard !isExpanded, store.chinState != .contextual, Defaults[.openNotchOnHover] else { return }

        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
            guard !Task.isCancelled else { return }
            expand()
        }
    }

    private func expand() {
        guard !isExpanded else { return }
        vm.open()
    }

    private func collapse() {
        guard isExpanded, !SharingStateManager.shared.preventNotchClose else { return }
        settleTask?.cancel()
        isOverAgenda = false
        vm.close()
    }

    private func settle() {
        settleTask?.cancel()
        settleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, !panelHoldsPointer else { return }
            collapse()
        }
    }

    private var panelHoldsPointer: Bool {
        guard let screen else { return false }
        let panel = CGRect(
            x: screen.frame.midX - panelSize.width / 2,
            y: screen.frame.maxY - surfaceTopInset(screen) - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
        return panel.contains(NSEvent.mouseLocation)
    }
}

#if DEBUG
#Preview {
    ExperienceView()
        .environmentObject(FlowDockViewModel())
        .frame(width: windowSize.width, height: windowSize.height)
}
#endif

//
//  SystemFeedback.swift
//  FlowDock
//

import AppKit
import SwiftUI

enum SystemFeedbackKind: Equatable {
    case volume(muted: Bool)
    case brightness
    case backlight
}

struct SystemFeedbackReading: Equatable {
    let kind: SystemFeedbackKind
    let value: CGFloat

    var title: String = ""

    var symbolName: String {
        switch kind {
        case .volume(let muted):
            return muted || value == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill"
        case .brightness:
            return "sun.max.fill"
        case .backlight:
            return "keyboard.fill"
        }
    }

    var symbolValue: Double? {
        switch kind {
        case .volume(let muted):
            return muted || value == 0 ? nil : Double(value)
        case .brightness, .backlight:
            return nil
        }
    }

    var label: String {
        switch kind {
        case .volume: "Volume"
        case .brightness: "Display brightness"
        case .backlight: "Keyboard backlight"
        }
    }
}

@MainActor
final class SystemFeedbackStore: ObservableObject {
    static let shared = SystemFeedbackStore()

    @Published private(set) var reading: SystemFeedbackReading?

    private var expiry: Task<Void, Never>?

    private init() {
        #if DEBUG
        Self.selfCheck()
        #endif
    }

    func report(_ kind: SystemFeedbackKind, value: CGFloat) {
        guard MediaKeyInterceptor.shared.isRunning else { return }

        reading = SystemFeedbackReading(
            kind: kind,
            value: min(max(value, 0), 1),
            title: Self.title(for: kind)
        )

        expiry?.cancel()
        expiry = Task { [weak self] in
            try? await Task.sleep(for: ActivityStore.contextualDwell)
            guard !Task.isCancelled else { return }
            self?.reading = nil
        }
    }

    private static func title(for kind: SystemFeedbackKind) -> String {
        switch kind {
        case .volume: VolumeManager.shared.outputDeviceName() ?? "Volume"
        case .brightness: "Display"
        case .backlight: "Keyboard"
        }
    }
}

#if DEBUG
extension SystemFeedbackStore {
    static func selfCheck() {
        func reading(_ kind: SystemFeedbackKind, _ value: CGFloat) -> SystemFeedbackReading {
            SystemFeedbackReading(kind: kind, value: value)
        }

        assert(reading(.volume(muted: false), 0).symbolName == "speaker.slash.fill")
        assert(reading(.volume(muted: true), 0.8).symbolName == "speaker.slash.fill")
        assert(reading(.volume(muted: true), 0.8).symbolValue == nil)
        assert(reading(.volume(muted: false), 0.5).symbolValue == 0.5)
        assert(reading(.brightness, 0).symbolName == "sun.max.fill")
        assert(reading(.backlight, 0).symbolName == "keyboard.fill")
    }
}
#endif

struct SystemFeedbackView: View {
    @EnvironmentObject private var vm: FlowDockViewModel
    @ObservedObject private var store = SystemFeedbackStore.shared
    @ObservedObject private var coordinator = FlowDockViewCoordinator.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    static let pillSize = CGSize(width: 236, height: 58)

    private var isActiveDisplay: Bool {
        vm.screenUUID == nil || vm.screenUUID == coordinator.selectedScreenUUID
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: vm.surfaceBottom + 8)

            if let reading = store.reading, isActiveDisplay {
                pill(reading)
                    .transition(.materialize(reduceMotion: reduceMotion))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.experience(reduceMotion: reduceMotion), value: vm.surfaceBottom)
        .animation(.experience(reduceMotion: reduceMotion, collapsing: true), value: store.reading)
    }

    private func pill(_ reading: SystemFeedbackReading) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(reading.title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            HStack(spacing: 10) {
                Image(systemName: reading.symbolName, variableValue: reading.symbolValue)
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 18, alignment: .leading)

                level(reading.value)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .frame(width: Self.pillSize.width, height: Self.pillSize.height, alignment: .leading)
        .glassBackground(reduceTransparency: reduceTransparency)
        .overlay(
            feedbackShape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.28), .white.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.5
            )
        )
        .shadow(color: .black.opacity(0.32), radius: 16, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.label)
        .accessibilityValue("\(Int(reading.value * 100)) percent")
    }

    private func level(_ value: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.18))

                Capsule()
                    .fill(.primary)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: geo.size.width * value)
                    }
            }
            .animation(.spring(response: 0.28, dampingFraction: 1.0), value: value)
        }
        .frame(height: 10)
    }
}

private let feedbackShape = RoundedRectangle(cornerRadius: 19, style: .continuous)

enum IconAppearance {
    case regular, clear, tinted

    static var current: IconAppearance {
        let theme = UserDefaults.standard.string(forKey: "AppleIconAppearanceTheme") ?? ""
        if theme.contains("Tinted") { return .tinted }
        if theme.contains("Clear") { return .clear }
        return .regular
    }
}

private extension View {
    @ViewBuilder
    func glassBackground(reduceTransparency: Bool) -> some View {
        if #available(macOS 26.0, *) {
            let glass: Glass = switch (reduceTransparency, IconAppearance.current) {
            case (true, _): .regular
            case (_, .clear): .clear
            case (_, .tinted): .clear.tint(.accentColor)
            case (_, .regular): .regular
            }
            glassEffect(glass, in: feedbackShape)
        } else {
            background(
                reduceTransparency ? AnyShapeStyle(.thickMaterial) : AnyShapeStyle(.ultraThinMaterial),
                in: feedbackShape
            )
        }
    }
}

final class SystemFeedbackWindow: NSPanel {
    static let height: CGFloat = openNotchSize.height + 8 + SystemFeedbackView.pillSize.height + shadowPadding

    init(viewModel: FlowDockViewModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: Self.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]

        contentView = NSHostingView(
            rootView: SystemFeedbackView().environmentObject(viewModel)
        )
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func attach(to parent: NSWindow) {
        level = parent.level
        setFrameOrigin(
            NSPoint(
                x: parent.frame.midX - frame.width / 2,
                y: parent.frame.maxY - frame.height
            ))
        parent.addChildWindow(self, ordered: .above)
    }
}

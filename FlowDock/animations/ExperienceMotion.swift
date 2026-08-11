//
//  ExperienceMotion.swift
//  FlowDock
//
//  The one transition, and the one place Reduce Motion is honored. See INTERACTION.md.
//

import AppKit
import SwiftUI

extension AnyTransition {
    /// The notch is above every surface FlowDock draws, so scaling toward the top edge
    /// makes content read as growing out of the cutout rather than fading in place.
    static let fromNotch: AnyTransition = .asymmetric(
        insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
        removal: .scale(scale: 0.96, anchor: .top)
            .combined(with: .opacity)
            .animation(.easeOut(duration: 0.18))
    )

    /// Reduce Motion keeps the duration and drops the movement.
    static func fromNotch(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .fromNotch
    }
}

enum ShellContinuity {
    static let musicArtwork = "music.artwork"
}

private struct ShellNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var shellNamespace: Namespace.ID? {
        get { self[ShellNamespaceKey.self] }
        set { self[ShellNamespaceKey.self] = newValue }
    }
}

extension View {
    /// An element that exists in both the chin and the panel moves between them rather than
    /// one copy fading out while another fades in. The namespace is nil under Reduce Motion,
    /// which is what turns the flight back into a cross-fade. See INTERACTION.md §Anchoring.
    @ViewBuilder
    func continuous(_ id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }
}

private struct Materialize: ViewModifier {
    let hidden: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: hidden ? 8 : 0)
            .scaleEffect(hidden ? 0.94 : 1, anchor: .top)
            .opacity(hidden ? 0 : 1)
    }
}

extension AnyTransition {
    static func materialize(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .modifier(active: Materialize(hidden: true), identity: Materialize(hidden: false))
    }
}

extension Animation {
    static func value(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.28, dampingFraction: 1.0)
    }

    static var value: Animation {
        value(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    /// Reduce Motion keeps the size change — size is the information — and drops the overshoot.
    static func experience(reduceMotion: Bool, collapsing: Bool = false) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.3) }
        return collapsing
            ? .spring(response: 0.45, dampingFraction: 1.0)
            : .spring(response: 0.42, dampingFraction: 0.8)
    }
}

private struct BounceOnAppear: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false

    func body(content: Content) -> some View {
        content
            .symbolEffect(.bounce, options: .nonRepeating, value: fired)
            .onAppear {
                guard !reduceMotion else { return }
                fired = true
            }
    }
}

extension View {
    func bounceOnAppear() -> some View {
        modifier(BounceOnAppear())
    }
}

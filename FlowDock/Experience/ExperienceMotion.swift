//
//  ExperienceMotion.swift
//  FlowDock
//
//  The one transition, and the one place Reduce Motion is honored. See INTERACTION.md.
//

import SwiftUI

extension AnyTransition {
    /// The notch is above every surface FlowDock draws, so scaling toward the top edge
    /// makes content read as growing out of the cutout rather than fading in place.
    static let fromNotch: AnyTransition = .scale(scale: 0.9, anchor: .top).combined(with: .opacity)

    /// Reduce Motion keeps the duration and drops the movement.
    static func fromNotch(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .fromNotch
    }
}

extension Animation {
    /// Reduce Motion keeps the size change — size is the information — and drops the overshoot.
    static func experience(reduceMotion: Bool, collapsing: Bool = false) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.3) }
        return collapsing
            ? .spring(response: 0.45, dampingFraction: 1.0)
            : .spring(response: 0.42, dampingFraction: 0.8)
    }
}

//
//  Typography.swift
//  FlowDock
//

import SwiftUI

extension Font {
    static let chinGlyph = Font.system(size: 13, weight: .medium)
    static let chinValue = Font.system(size: 12, weight: .semibold)
    /// The glyph on the mark beside the chin, which is a smaller circle than the chin.
    static let markGlyph = Font.system(size: 10, weight: .medium)
    static let panelControl = Font.system(size: 15, weight: .medium)
    static let panelPrimary = Font.system(size: 18, weight: .medium)
    static let panelMeta = Font.system(size: 11, weight: .medium)
    /// The clock on the lock screen, which is read across a room rather than at a desk.
    static let lockClock = Font.system(size: 44, weight: .light)
}

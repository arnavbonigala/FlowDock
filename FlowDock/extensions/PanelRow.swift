//
//  PanelRow.swift
//  FlowDock
//

import SwiftUI

/// DESIGN.md §4 allows two row heights in the panel: one for a row that carries content,
/// one for a strip that only carries controls. A third is a new layout, not a new number.
enum PanelRow {
    static let content: CGFloat = 30
    static let controls: CGFloat = 22
}

extension View {
    func panelRowBackground(cornerRadius: CGFloat = 8) -> some View {
        modifier(PanelRowBackground(cornerRadius: cornerRadius))
    }
}

extension ShapeStyle where Self == AnyShapeStyle {
    /// A region with no border of its own, whose edge is the fill. Increase Contrast steps
    /// it up a tier so it does not disappear into the panel. See DESIGN.md §3.
    static func raised(_ contrast: ColorSchemeContrast) -> AnyShapeStyle {
        contrast == .increased ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quaternary)
    }
}

private struct PanelRowBackground: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content.background {
            shape
                .fill(.raised(contrast))
                .overlay(shape.strokeBorder(.primary, lineWidth: contrast == .increased ? 1 : 0))
        }
    }
}

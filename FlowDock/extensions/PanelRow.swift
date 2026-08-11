//
//  PanelRow.swift
//  FlowDock
//

import SwiftUI

extension View {
    func panelRowBackground(cornerRadius: CGFloat = 8) -> some View {
        modifier(PanelRowBackground(cornerRadius: cornerRadius))
    }
}

private struct PanelRowBackground: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content.background {
            shape
                .fill(contrast == .increased ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quaternary))
                .overlay(shape.strokeBorder(.primary, lineWidth: contrast == .increased ? 1 : 0))
        }
    }
}

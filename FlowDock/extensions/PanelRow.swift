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
        raisedSurface(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// A region with no border of its own, whose edge is the fill. Increase Contrast steps the
    /// fill up a tier and adds the hairline the fill alone was standing in for. See DESIGN.md §3.
    func raisedSurface(_ shape: some InsettableShape) -> some View {
        modifier(RaisedSurface(shape: shape))
    }
}

extension View {
    /// Reports how long the scrollable content is, for the enclosing `fadesPastEdge`.
    func measuring(_ length: Binding<CGFloat>, along axis: Axis) -> some View {
        background {
            GeometryReader { proxy in
                let size = axis == .horizontal ? proxy.size.width : proxy.size.height
                Color.clear.onChange(of: size, initial: true) { _, now in length.wrappedValue = now }
            }
        }
    }

    /// A region that runs past its edge has to say so. FlowDock hides scroll indicators
    /// because a scrollbar inside the bezel reads as a window, so the edge itself carries
    /// the news. macOS 14 cannot report a scroll offset, so the fade marks the edge rather
    /// than tracking distance travelled, and it is absent whenever everything fits.
    func fadesPastEdge(_ axis: Axis, contentLength: CGFloat) -> some View {
        modifier(EdgeFade(axis: axis, contentLength: contentLength))
    }
}

private struct EdgeFade: ViewModifier {
    let axis: Axis
    let contentLength: CGFloat

    @State private var visibleLength: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    let size = axis == .horizontal ? proxy.size.width : proxy.size.height
                    Color.clear.onChange(of: size, initial: true) { _, now in visibleLength = now }
                }
            }
            .mask(alignment: axis == .horizontal ? .leading : .top) { fade }
    }

    @ViewBuilder
    private var fade: some View {
        if contentLength > visibleLength + 1 {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1),
                ],
                startPoint: axis == .horizontal ? .leading : .top,
                endPoint: axis == .horizontal ? .trailing : .bottom
            )
        } else {
            Color.black
        }
    }
}

extension ShapeStyle where Self == AnyShapeStyle {
    static func raised(_ contrast: ColorSchemeContrast) -> AnyShapeStyle {
        contrast == .increased ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quaternary)
    }
}

private struct RaisedSurface<S: InsettableShape>: ViewModifier {
    let shape: S

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.background {
            shape
                .fill(.raised(contrast))
                .overlay(shape.strokeBorder(.primary, lineWidth: contrast == .increased ? 1 : 0))
        }
    }
}

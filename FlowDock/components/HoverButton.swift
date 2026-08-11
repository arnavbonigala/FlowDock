//
//  HoverButton.swift
//  FlowDock
//
//  Created by Kraigo on 04.09.2024.
//

import SwiftUI

struct HoverButton: View {
    var icon: String
    var iconColor: Color = .primary
    var scale: Image.Scale = .medium
    var action: () -> Void
    var contentTransition: ContentTransition = .symbolEffect;
    
    @State private var isHovering = false

    var body: some View {
        let size = CGFloat(scale == .large ? 40 : 30)
        let glyph: Font = switch scale {
        case .large: .largeTitle
        case .small: .panelMeta
        default: .panelControl
        }

        Button(action: action) {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(width: size, height: size)
                .overlay {
                    Capsule()
                        .fill(isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
                        .frame(width: size, height: size)
                        .overlay {
                            Image(systemName: icon)
                                .foregroundColor(iconColor)
                                .contentTransition(contentTransition)
                                .font(glyph)
                        }
                }
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { hovering in
            withAnimation(.value) {
                isHovering = hovering
            }
        }
    }
}

extension View {
    func iconLabel(_ text: String) -> some View {
        accessibilityLabel(text).help(text)
    }
}

struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.value(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

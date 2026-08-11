//
//  MarqueeTextView.swift
//  FlowDock
//
//  Created by Richard Kunkli on 08/08/2024.
//

import SwiftUI

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct MeasureSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(GeometryReader { geometry in
            Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
        })
    }
}

struct MarqueeText: View {
    @Binding var text: String
    let font: Font
    let nsFont: NSFont.TextStyle
    let textColor: Color
    let backgroundColor: Color
    let minDuration: Double
    let frameWidth: CGFloat
    /// Where text that is too short to scroll sits. Text long enough to scroll fills the
    /// width, so it starts from the leading edge whatever this says.
    let alignment: Alignment
    
    @State private var animate = false
    @State private var textSize: CGSize = .zero
    @State private var offset: CGFloat = 0

    private let gap: CGFloat = 24
    
    init(_ text: Binding<String>, font: Font = .body, nsFont: NSFont.TextStyle = .body, textColor: Color = .primary, backgroundColor: Color = .clear, minDuration: Double = 3.0, frameWidth: CGFloat = 200, alignment: Alignment = .leading) {
        _text = text
        self.font = font
        self.nsFont = nsFont
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.minDuration = minDuration
        self.frameWidth = frameWidth
        self.alignment = alignment
    }
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var needsScrolling: Bool {
        textSize.width > frameWidth && !reduceMotion
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: needsScrolling ? .leading : alignment) {
                HStack(spacing: gap) {
                    Text(text)
                    Text(text)
                        .opacity(needsScrolling ? 1 : 0)
                }
                .id(text)
                .font(font)
                .foregroundColor(textColor)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: self.animate ? offset : 0)
                .animation(
                    self.animate ?
                        .linear(duration: Double((textSize.width + gap) / 30))
                        .delay(minDuration)
                        .repeatForever(autoreverses: false) : .none,
                    value: self.animate
                )
                .background(backgroundColor)
                .modifier(MeasureSizeModifier())
                .onPreferenceChange(SizePreferenceKey.self) { size in
                    self.textSize = CGSize(width: size.width / 2 - gap / 2, height: NSFont.preferredFont(forTextStyle: nsFont).pointSize)
                    self.animate = false
                    self.offset = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01){
                        if needsScrolling {
                            self.animate = true
                            self.offset = -(textSize.width + gap)
                            
                        }
                    }
                }
            }
            .frame(width: frameWidth, alignment: needsScrolling ? .leading : alignment)
            .clipped()
        }
        .frame(height: textSize.height * 1.3)
        
    }
}

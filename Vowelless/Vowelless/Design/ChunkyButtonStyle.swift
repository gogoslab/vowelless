import SwiftUI

/// A toy-like button with a solid base that it sinks into when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color
    var foreground: Color = .white
    var depth: CGFloat = 6
    var cornerRadius: CGFloat = 20
    var horizontalPadding: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 14)
            .background(shape.fill(LinearGradient(colors: [color.mix(with: .white, by: 0.15), color], startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 2))
            .background(
                shape.fill(color.darker())
                    .offset(y: pressed ? 0 : depth)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: pressed ? 2 : 5)
            )
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .animation(.spring(duration: 0.18, bounce: 0.4), value: pressed)
            .onChange(of: pressed) { _, isPressed in
                if isPressed { Sounds.play(.tap) }
            }
    }
}

/// Wobbles horizontally each time `trigger` increases.
struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * 4), y: 0))
    }
}

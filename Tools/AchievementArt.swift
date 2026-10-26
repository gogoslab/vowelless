// Renders the 512x512 Game Center achievement badges into Tools/AchievementImages.
// Run from the repository root: swift Tools/AchievementArt.swift

import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

let badges: [(id: String, symbol: String, color: Color)] = [
    ("firstClue", "textformat.abc", Color(red: 1.0, green: 0.36, blue: 0.64)),
    ("clues100", "target", Color(red: 1.0, green: 0.79, blue: 0.24)),
    ("clues500", "crown.fill", Color(red: 1.0, green: 0.35, blue: 0.37)),
    ("clean50", "hand.thumbsup.fill", Color(red: 0.13, green: 0.76, blue: 0.76)),
    ("hard25", "flame.fill", Color(red: 1.0, green: 0.35, blue: 0.37)),
    ("flawless", "sparkles", Color(red: 0.65, green: 0.88, blue: 0.25)),
    ("firstWin", "bolt.fill", Color(red: 1.0, green: 0.36, blue: 0.64)),
    ("wins10", "flag.checkered", Color(red: 0.13, green: 0.76, blue: 0.76)),
    ("wins50", "trophy.fill", Color(red: 1.0, green: 0.79, blue: 0.24)),
    ("quickDraw", "stopwatch.fill", Color(red: 0.24, green: 0.84, blue: 0.55)),
    ("comeback", "arrow.uturn.up", Color(red: 0.24, green: 0.55, blue: 1.0)),
    ("dailyFirst", "calendar", Color(red: 0.24, green: 0.55, blue: 1.0)),
    ("dailyPerfect", "star.fill", Color(red: 1.0, green: 0.79, blue: 0.24)),
    ("streak7", "flame.fill", Color(red: 1.0, green: 0.54, blue: 0.24)),
    ("streak30", "infinity", Color(red: 1.0, green: 0.36, blue: 0.64)),
]

struct Badge: View {
    let symbol: String
    let color: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 96, style: .continuous)
        ZStack {
            LinearGradient(colors: [Color(red: 0.36, green: 0.24, blue: 1.0), Color(red: 0.66, green: 0.22, blue: 0.92)],
                           startPoint: .top, endPoint: .bottom)
            Image(systemName: symbol)
                .font(.system(size: 170, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 0, y: 8)
                .frame(width: 330, height: 330)
                .background(shape.fill(LinearGradient(colors: [color.mix(with: .white, by: 0.3), color], startPoint: .top, endPoint: .bottom)))
                .overlay(shape.strokeBorder(.white.opacity(0.6), lineWidth: 8))
                .background(shape.fill(color.mix(with: .black, by: 0.3)).offset(y: 40))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 50)
                .rotationEffect(.degrees(-4))
                .offset(y: -16)
        }
        .frame(width: 512, height: 512)
    }
}

@MainActor
func render() throws {
    for badge in badges {
        let renderer = ImageRenderer(content: Badge(symbol: badge.symbol, color: badge.color))
        renderer.scale = 1
        guard let image = renderer.cgImage else { throw NSError(domain: "art", code: 1) }
        // Opaque, as Game Center expects.
        let context = CGContext(data: nil, width: 512, height: 512, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 512, height: 512))
        let url = URL(fileURLWithPath: "Tools/AchievementImages/\(badge.id).png")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "art", code: 2) }
    }
    print("Wrote \(badges.count) badges")
}

try MainActor.assumeIsolated { try render() }

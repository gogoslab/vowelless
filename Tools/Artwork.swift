// Renders the app icon and the launch screen logo into the asset catalog.
// Run from the repository root: swift Tools/Artwork.swift
// Colors and tile shapes mirror Theme.swift and LetterTile.swift.

import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

let size: CGFloat = 1024

extension Color {
    init(_ r: Double, _ g: Double, _ b: Double) { self.init(red: r, green: g, blue: b) }
    func darker(_ amount: Double = 0.3) -> Color { mix(with: .black, by: amount) }
}

enum Palette {
    static let top = Color(0.36, 0.24, 1.0)
    static let bottom = Color(0.66, 0.22, 0.92)
    static let pink = Color(1.0, 0.36, 0.64)
    static let yellow = Color(1.0, 0.79, 0.24)
    static let red = Color(1.0, 0.35, 0.37)
    static let teal = Color(0.13, 0.76, 0.76)
    static let green = Color(0.24, 0.84, 0.55)
    static let lime = Color(0.65, 0.88, 0.25)
    static let ink = Color(0.16, 0.10, 0.30)
}

struct Tile: View {
    let letter: String
    let face: Color
    let ink: Color
    let side: CGFloat
    var fontScale: CGFloat = 0.6

    var body: some View {
        let depth = side * 0.13
        let shape = RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
        Text(letter)
            .font(.system(size: side * fontScale, weight: .black, design: .rounded))
            .foregroundStyle(ink)
            .frame(width: side, height: side)
            .background(shape.fill(LinearGradient(colors: [face.mix(with: .white, by: 0.3), face], startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(.white.opacity(0.6), lineWidth: side * 0.025))
            .background(shape.fill(face.darker(0.28)).offset(y: depth))
            .padding(.bottom, depth)
            .shadow(color: .black.opacity(0.3), radius: side * 0.06, y: depth + side * 0.04)
    }
}

struct Icon: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.top, Palette.bottom], startPoint: .top, endPoint: .bottom)
            Circle().fill(Palette.pink.opacity(0.55)).frame(width: 620).blur(radius: 140).offset(x: -300, y: -330)
            Circle().fill(Palette.teal.opacity(0.5)).frame(width: 560).blur(radius: 140).offset(x: 330, y: 360)

            HStack(spacing: 18) {
                Tile(letter: "V", face: Palette.pink, ink: .white, side: 270)
                    .rotationEffect(.degrees(-8))
                    .offset(y: 30)
                Tile(letter: "W", face: Palette.yellow, ink: Palette.ink, side: 270)
                    .rotationEffect(.degrees(4))
                    .offset(y: -30)
                Tile(letter: "L", face: Palette.teal, ink: .white, side: 270)
                    .rotationEffect(.degrees(-3))
                    .offset(y: 20)
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

/// The "VWLLSS" title from the home screen, on a transparent background.
/// Sized like LetterTile at Theme.titleTileSize so the launch screen hands off seamlessly to SplashView.
struct LaunchLogo: View {
    static let letters = Array("VWLLSS")
    static let colors = [Palette.pink, Palette.yellow, Palette.red, Palette.teal, Palette.green, Palette.lime]
    static let tilts: [Double] = [-4, 3, -2, 5, -3, 2] // Theme.tilt

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.letters.count, id: \.self) { i in
                Tile(letter: String(Self.letters[i]), face: Self.colors[i], ink: .white, side: 50, fontScale: 0.56)
                    .rotationEffect(.degrees(Self.tilts[i]))
            }
        }
        .padding(16)
    }
}

let assets = "Vowelless/Vowelless/Resources/Assets.xcassets"

func writePNG(_ image: CGImage, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "artwork", code: 2) }
    print("Wrote \(path) (\(image.width)×\(image.height))")
}

@MainActor
func renderIcon() throws {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = 1
    guard let rendered = renderer.cgImage else { throw NSError(domain: "artwork", code: 1) }

    // App Store icons must be opaque: redraw without an alpha channel.
    let context = CGContext(
        data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.draw(rendered, in: CGRect(x: 0, y: 0, width: size, height: size))
    try writePNG(context.makeImage()!, to: "\(assets)/AppIcon.appiconset/AppIcon.png")
}

@MainActor
func renderLaunchLogo() throws {
    for scale in [2, 3] {
        let renderer = ImageRenderer(content: LaunchLogo())
        renderer.scale = CGFloat(scale)
        guard let image = renderer.cgImage else { throw NSError(domain: "artwork", code: 1) }
        try writePNG(image, to: "\(assets)/LaunchLogo.imageset/LaunchLogo@\(scale)x.png")
    }
}

try MainActor.assumeIsolated {
    try renderIcon()
    try renderLaunchLogo()
}

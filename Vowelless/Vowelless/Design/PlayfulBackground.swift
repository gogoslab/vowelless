import SwiftUI

struct PlayfulBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.backgroundTop, Theme.backgroundBottom], startPoint: .top, endPoint: .bottom)
            blob(Category.song.color, size: 260, x: -140, y: -300)
            blob(Category.tvShow.color, size: 220, x: 160, y: -60)
            blob(Category.artist.color, size: 240, x: -120, y: 320)
        }
        .ignoresSafeArea()
        .onAppear { drift = true }
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.45))
            .frame(width: size, height: size)
            .blur(radius: 60)
            .offset(x: drift ? x + 30 : x, y: drift ? y - 20 : y)
            .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: drift)
    }
}

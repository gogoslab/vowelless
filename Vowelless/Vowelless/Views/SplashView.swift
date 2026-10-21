import SwiftUI

/// Picks up where the launch screen leaves off: the title tiles hop from the center
/// up to their place on the home screen while the launch background fades away.
struct SplashView: View {
    /// The home screen title's frame, in global coordinates.
    let target: CGRect?
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let travel = target.map { CGSize(width: $0.midX - frame.midX, height: $0.midY - frame.midY) } ?? .zero
            ZStack {
                Color("LaunchBackground")
                    .opacity(landed ? 0 : 1)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: landed)

                // Same layout as the launch screen's LaunchLogo, centered on the full screen.
                HStack(spacing: 6) {
                    ForEach(Theme.title.indices, id: \.self) { i in
                        LetterTile.title(i)
                            .offset(landed && !reduceMotion ? travel : .zero)
                            .animation(.spring(duration: 0.55, bounce: 0.3).delay(Double(i) * 0.05), value: landed)
                    }
                }
                .opacity(landed && reduceMotion ? 0 : 1)
                .animation(.easeOut(duration: 0.3), value: landed)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(!landed)
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            landed = true
            try? await Task.sleep(for: .milliseconds(1100))
            onFinish()
        }
    }
}

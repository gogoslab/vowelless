import SwiftUI

enum Theme {
    static let ink = Color(red: 0.16, green: 0.10, blue: 0.30)
    static let tileFace = Color(red: 1.0, green: 0.97, blue: 0.90)
    static let backgroundTop = Color(red: 0.36, green: 0.24, blue: 1.0)
    static let backgroundBottom = Color(red: 0.66, green: 0.22, blue: 0.92)
    static let orange = Color(red: 1.0, green: 0.54, blue: 0.24)
    static let correct = Color(red: 0.24, green: 0.84, blue: 0.55)
    static let wrong = Color(red: 1.0, green: 0.36, blue: 0.40)

    static let palette: [Color] = Category.allCases.map(\.color)

    /// The home screen title, also drawn by the launch screen and SplashView.
    static let title = Array("VWLLSS")
    static let titleTileSize: CGFloat = 50

    /// Small deterministic tilt so tiles look hand-placed.
    static func tilt(_ n: Int) -> Angle {
        let angles: [Double] = [-4, 3, -2, 5, -3, 2, -5, 4]
        return .degrees(angles[abs(n) % angles.count])
    }
}

extension Color {
    func darker(_ amount: Double = 0.3) -> Color { mix(with: .black, by: amount) }
}

extension Category {
    var color: Color {
        switch self {
        case .song: Color(red: 1.0, green: 0.36, blue: 0.64)
        case .artist: Color(red: 1.0, green: 0.79, blue: 0.24)
        case .movie: Color(red: 1.0, green: 0.35, blue: 0.37)
        case .tvShow: Color(red: 0.13, green: 0.76, blue: 0.76)
        case .character: Color(red: 0.24, green: 0.84, blue: 0.55)
        case .book: Color(red: 0.24, green: 0.55, blue: 1.0)
        case .famous: Color(red: 0.65, green: 0.88, blue: 0.25)
        case .place: Color(red: 0.40, green: 0.78, blue: 1.0)
        case .brand: Theme.orange
        case .team: Color(red: 0.18, green: 0.20, blue: 0.36)
        }
    }

    /// Text color that stays readable on `color`.
    var onColor: Color { [.artist, .famous, .place].contains(self) ? Theme.ink : .white }
}

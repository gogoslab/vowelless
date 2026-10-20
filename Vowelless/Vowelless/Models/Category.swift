import Foundation

enum Category: String, Codable, CaseIterable, Identifiable {
    case song, artist, movie, tvShow, character, famous, book, place, brand, team

    var id: String { rawValue }

    var title: String {
        switch self {
        case .song: "Songs"
        case .artist: "Artists & Bands"
        case .movie: "Movies"
        case .tvShow: "TV Shows"
        case .character: "Characters"
        case .book: "Books"
        case .famous: "Famous People"
        case .place: "Places"
        case .brand: "Brands"
        case .team: "Sports Teams"
        }
    }

    var symbol: String {
        switch self {
        case .song: "music.note"
        case .artist: "music.mic"
        case .movie: "film"
        case .tvShow: "tv"
        case .character: "person.crop.circle"
        case .book: "book"
        case .famous: "star.fill"
        case .place: "globe.europe.africa.fill"
        case .brand: "tag.fill"
        case .team: "trophy.fill"
        }
    }
}

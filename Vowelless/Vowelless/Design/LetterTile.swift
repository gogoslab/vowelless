import SwiftUI

/// A Scrabble-like tile with a visible side so it reads as 3D.
struct LetterTile: View {
    let letter: Character
    var size: CGFloat = 44
    var face: Color = Theme.tileFace
    var ink: Color = Theme.ink
    var tilt: Angle = .zero

    var body: some View {
        let depth = size * 0.13
        let shape = RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        Text(String(letter))
            .font(.system(size: size * 0.56, weight: .black, design: .rounded))
            .foregroundStyle(ink)
            .frame(width: size, height: size)
            .background(shape.fill(LinearGradient(colors: [face.mix(with: .white, by: 0.3), face], startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
            .background(shape.fill(face.darker(0.28)).offset(y: depth))
            .padding(.bottom, depth)
            .shadow(color: .black.opacity(0.25), radius: 3, y: depth + 2)
            .rotationEffect(tilt)
    }
}

extension LetterTile {
    /// The `i`th tile of the "VWLLSS" title.
    static func title(_ i: Int) -> LetterTile {
        LetterTile(letter: Theme.title[i], size: Theme.titleTileSize, face: Theme.palette[i % Theme.palette.count], ink: .white, tilt: Theme.tilt(i))
    }
}

private struct StartsWordKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    /// Marks a tile as the first of a word, so `TileFlowLayout` puts a word gap before it.
    func startsWord(_ value: Bool) -> some View {
        layoutValue(key: StartsWordKey.self, value: value)
    }
}

/// Lays tiles out in centered lines. Words wrap as a whole; a word wider than the line breaks between tiles.
struct TileFlowLayout: Layout {
    var tileSpacing: CGFloat
    var wordSpacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        // Wrap against the proposed width, not `bounds`: bounds is our own fitted width and
        // re-wrapping against it can push the last tile to a new line due to rounding.
        for line in arrange(maxWidth: (proposal.width ?? bounds.width) + 0.5, subviews: subviews) {
            let left = bounds.minX + (bounds.width - line.width) / 2
            for item in line.items {
                let size = subviews[item.index].sizeThatFits(.unspecified)
                subviews[item.index].place(at: CGPoint(x: left + item.x, y: y), proposal: ProposedViewSize(size))
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var items: [(index: Int, x: CGFloat)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func add(_ index: Int, size: CGSize, gap: CGFloat) {
            let x = items.isEmpty ? 0 : width + gap
            items.append((index, x))
            width = x + size.width
            height = max(height, size.height)
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var words: [[Int]] = []
        for index in subviews.indices {
            if words.isEmpty || subviews[index][StartsWordKey.self] {
                words.append([index])
            } else {
                words[words.count - 1].append(index)
            }
        }

        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var lines: [Line] = []
        var current = Line()

        for word in words {
            let wordWidth = word.map { sizes[$0].width }.reduce(0, +) + tileSpacing * CGFloat(word.count - 1)
            let fitsOnCurrent = current.items.isEmpty || current.width + wordSpacing + wordWidth <= maxWidth

            if wordWidth <= maxWidth {
                if !fitsOnCurrent {
                    lines.append(current)
                    current = Line()
                }
                for (k, index) in word.enumerated() {
                    current.add(index, size: sizes[index], gap: k == 0 ? wordSpacing : tileSpacing)
                }
            } else {
                // Too long for any line: break it between tiles.
                for (k, index) in word.enumerated() {
                    let gap = k == 0 ? wordSpacing : tileSpacing
                    if !current.items.isEmpty, current.width + gap + sizes[index].width > maxWidth {
                        lines.append(current)
                        current = Line()
                    }
                    current.add(index, size: sizes[index], gap: gap)
                }
            }
        }
        if !current.items.isEmpty { lines.append(current) }
        return lines
    }
}

/// The clue as tiles. When `revealed`, the tiles slide into the real answer and the missing vowels pop in.
struct ClueBoard: View {
    let answer: String
    let revealed: Bool
    var difficulty: Difficulty = .easy
    /// Vowels the player chose to reveal before the answer.
    var revealedVowels: Set<Character> = []
    var accent: Color = Category.song.color
    var maxWidth: CGFloat = 320
    var maxTileSize: CGFloat = 48

    private struct Placed: Identifiable {
        let tile: ClueTile
        let startsWord: Bool
        var id: Int { tile.id }
    }

    var body: some View {
        let words = Disemvoweler.letters(of: answer)
        let longest = CGFloat(words.map(\.count).max() ?? 1)
        let size = min(maxTileSize, maxWidth / (longest * 1.12))

        TileFlowLayout(tileSpacing: size * 0.12, wordSpacing: size * 0.7, lineSpacing: size * 0.3) {
            ForEach(placedTiles) { placed in
                let tile = placed.tile
                LetterTile(
                    letter: tile.letter,
                    size: size,
                    face: tile.isVowel ? accent : Theme.tileFace,
                    ink: tile.isVowel ? .white : Theme.ink,
                    tilt: Theme.tilt(tile.id)
                )
                .startsWord(placed.startsWord)
                .transition(.scale(scale: 0.1).combined(with: .opacity))
            }
        }
    }

    private var placedTiles: [Placed] {
        if revealed {
            var previousWord = -1
            return Disemvoweler.tiles(of: answer).map { tile in
                defer { previousWord = tile.wordIndex }
                return Placed(tile: tile, startsWord: tile.wordIndex != previousWord)
            }
        }
        return Disemvoweler.clueGroups(for: answer, difficulty: difficulty, revealedVowels: revealedVowels).flatMap { group in
            group.enumerated().map { Placed(tile: $1, startsWord: $0 == 0) }
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        ForEach(Difficulty.allCases) { difficulty in
            ClueBoard(answer: "Bohemian Rhapsody", revealed: false, difficulty: difficulty)
        }
        ClueBoard(answer: "Bohemian Rhapsody", revealed: true)
    }
    .padding()
    .background(PlayfulBackground())
}

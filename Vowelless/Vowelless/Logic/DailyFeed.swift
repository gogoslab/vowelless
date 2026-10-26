import Foundation

/// Daily puzzles published in Firebase Realtime Database, laid out as `daily/{year}/{month}/{day}`,
/// each day being a list of puzzles. A month is downloaded once and kept on the phone; after that
/// the local copy is used (the published puzzles aren't expected to change).
final class DailyFeed: @unchecked Sendable {
    /// One puzzle as stored online. Only `answer` and `category` are required: for answers that
    /// are already in the app, the rest is filled in from the bundled puzzles.
    struct Entry: Codable {
        let answer: String
        let category: Category
        var level: PuzzleLevel?
        var hints: [String]?

        var puzzle: Puzzle {
            let bundled = PuzzleStore.builtIn.first { $0.answer == answer && $0.category == category }
            return Puzzle(
                answer: answer,
                category: category,
                level: level ?? bundled?.level ?? .easy,
                hints: hints ?? bundled?.hints ?? []
            )
        }
    }

    /// The database root, e.g. https://vowelless-default-rtdb.europe-west1.firebasedatabase.app
    /// (`VWLDailyPuzzlesURL` in Info.plist). Without it, the app picks daily puzzles itself.
    let baseURL: URL?
    private let folder: URL
    private let session: URLSession
    private let calendar: Calendar

    init(baseURL: URL? = DailyFeed.configuredURL, folder: URL? = nil, session: URLSession = .shared, calendar: Calendar = .current) {
        self.baseURL = baseURL
        self.session = session
        self.calendar = calendar
        self.folder = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DailyPuzzles", isDirectory: true)
    }

    static var configuredURL: URL? {
        guard let string = Bundle.main.object(forInfoDictionaryKey: "VWLDailyPuzzlesURL") as? String,
              !string.isEmpty else { return nil }
        return URL(string: string)
    }

    // MARK: - Reading

    /// The day's puzzles from the stored month, if that month was downloaded and has the day.
    func puzzles(for date: Date) -> [Puzzle]? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let data = try? Data(contentsOf: fileURL(year: year, month: month)),
              let days = try? Self.decodeMonth(data),
              let entries = days[day], !entries.isEmpty else { return nil }
        return entries.map(\.puzzle)
    }

    func hasMonth(containing date: Date) -> Bool {
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let year = parts.year, let month = parts.month else { return false }
        return FileManager.default.fileExists(atPath: fileURL(year: year, month: month).path)
    }

    // MARK: - Downloading

    /// Downloads this month if it isn't stored yet, and next month too during the last days of the month.
    func refresh(now: Date = .now) async {
        await download(monthContaining: now)
        if let day = calendar.dateComponents([.day], from: now).day, day >= 25,
           let next = calendar.date(byAdding: .month, value: 1, to: now) {
            await download(monthContaining: next)
        }
    }

    func download(monthContaining date: Date) async {
        guard let baseURL, !hasMonth(containing: date) else { return }
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let year = parts.year, let month = parts.month else { return }
        let url = baseURL
            .appendingPathComponent("daily")
            .appendingPathComponent(String(year))
            .appendingPathComponent(String(format: "%02d", month) + ".json")
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let days = try? Self.decodeMonth(data), !days.isEmpty else { return }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: fileURL(year: year, month: month), options: .atomic)
        } catch {
            // Offline or not published yet: try again next launch; the app falls back to its own picks.
        }
    }

    // MARK: - Format

    /// A month is `{"01": [puzzle, ...], "02": [...]}`. Firebase may return day keys that look like
    /// numbers as an array instead (index = day), so both shapes are accepted.
    static func decodeMonth(_ data: Data) throws -> [Int: [Entry]] {
        let json = try JSONSerialization.jsonObject(with: data)
        var raw: [(Int, Any)] = []
        if let dictionary = json as? [String: Any] {
            raw = dictionary.compactMap { key, value in Int(key).map { ($0, value) } }
        } else if let array = json as? [Any] {
            raw = array.enumerated().map { ($0.offset, $0.element) }
        }
        var days: [Int: [Entry]] = [:]
        for (day, value) in raw where value is [Any] {
            let entryData = try JSONSerialization.data(withJSONObject: value)
            if let entries = try? JSONDecoder().decode([Entry].self, from: entryData), !entries.isEmpty {
                days[day] = entries
            }
        }
        return days
    }

    private func fileURL(year: Int, month: Int) -> URL {
        folder.appendingPathComponent(String(format: "%04d-%02d.json", year, month))
    }
}

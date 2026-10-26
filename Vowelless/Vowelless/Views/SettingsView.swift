import SwiftUI

struct SettingsView: View {
    @AppStorage(Difficulty.storageKey) private var difficulty: Difficulty = .easy
    @AppStorage(MusicSource.storageKey) private var musicSource: MusicSource = .builtIn
    @Environment(MusicLibrary.self) private var library
    @Environment(RewardedAds.self) private var ads
    @AppStorage(Sounds.enabledKey) private var soundsEnabled = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Settings")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black))
                    }
                    .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 4, cornerRadius: 14))
                }
                .foregroundStyle(.white)

                Text("Difficulty")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.9))

                ForEach(Difficulty.allCases) { option in
                    difficultyCard(option)
                }

                Text("Songs, Artists & Bands")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 12)

                musicSourceCard

                Toggle(isOn: $soundsEnabled) {
                    Label("Sound effects", systemImage: soundsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.correct)
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.darker(0.3)).offset(y: 5))
                .padding(.top, 12)
                .onChange(of: soundsEnabled) { _, on in if on { Sounds.play(.pop) } }

                if ads.privacyOptionsRequired {
                    Button {
                        Task { await ads.showPrivacyOptions() }
                    } label: {
                        Label("Ad privacy choices", systemImage: "hand.raised.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: .white, foreground: Theme.ink, depth: 5, cornerRadius: 20))
                    .padding(.top, 12)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(PlayfulBackground())
        .sensoryFeedback(.selection, trigger: difficulty)
        .sensoryFeedback(.selection, trigger: musicSource)
    }

    // MARK: - Music library

    private var musicSourceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Use my Music library", systemImage: "music.note.house.fill")
                .font(.system(.title3, design: .rounded, weight: .black))
            Text("Make puzzles from the songs and artists on this iPhone.")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .opacity(0.75)

            HStack(spacing: 10) {
                ForEach(MusicSource.allCases) { option in
                    let selected = option == musicSource
                    Button {
                        withAnimation(.spring(bounce: 0.4)) { musicSource = option }
                        if option.usesLibrary { Task { await library.load() } }
                    } label: {
                        Text(option.title)
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChunkyButtonStyle(
                        color: selected ? Category.song.color : Theme.tileFace,
                        foreground: selected ? .white : Theme.ink,
                        depth: selected ? 6 : 4,
                        cornerRadius: 16,
                        horizontalPadding: 8
                    ))
                }
            }

            if musicSource.usesLibrary {
                libraryStatus
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.darker(0.3)).offset(y: 5))
        .padding(.bottom, 5)
    }

    @ViewBuilder
    private var libraryStatus: some View {
        switch library.status {
        case .notDetermined:
            Label("Vowelless will ask to access your Music library.", systemImage: "info.circle.fill")
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Reading your library…")
            }
        case .loaded where library.puzzles.isEmpty:
            Label("No music found on this device, so the built-in list is used.", systemImage: "music.note.list")
        case .loaded:
            Label(
                "Found \(library.count(of: .song)) songs and \(library.count(of: .artist)) artists & bands.",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(Theme.correct.darker(0.2))
        case .denied:
            VStack(alignment: .leading, spacing: 10) {
                Label("Music access is turned off, so the built-in list is used.", systemImage: "lock.fill")
                    .foregroundStyle(Theme.wrong)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.ink, depth: 4, cornerRadius: 14))
            }
        case .restricted:
            Label("The Music library isn't available on this device.", systemImage: "nosign")
                .foregroundStyle(Theme.wrong)
        }
    }

    private func difficultyCard(_ option: Difficulty) -> some View {
        let selected = option == difficulty
        let color = color(for: option)
        return Button {
            withAnimation(.spring(bounce: 0.4)) { difficulty = option }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(option.title, systemImage: option.symbol)
                        .font(.system(.title2, design: .rounded, weight: .black))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26, weight: .bold))
                }
                Text(option.subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .opacity(0.8)
                ClueBoard(answer: "Harry Potter", revealed: false, difficulty: option, maxWidth: 260, maxTileSize: 26)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .buttonStyle(ChunkyButtonStyle(
            color: selected ? color : .white,
            foreground: selected ? .white : Theme.ink,
            depth: selected ? 8 : 5,
            cornerRadius: 24
        ))
    }

    private func color(for option: Difficulty) -> Color {
        switch option {
        case .easy: Category.character.color
        case .medium: Theme.orange
        case .hard: Theme.wrong
        }
    }
}

#Preview {
    SettingsView()
        .fontDesign(.rounded)
        .environment(MusicLibrary())
        .environment(RewardedAds())
}

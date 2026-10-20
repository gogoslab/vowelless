import SwiftUI

@main
struct VowellessApp: App {
    @State private var library = MusicLibrary()
    @AppStorage(MusicSource.storageKey) private var musicSource: MusicSource = .builtIn

    var body: some Scene {
        WindowGroup {
            HomeView()
                .fontDesign(.rounded)
                .preferredColorScheme(.dark)
                .environment(library)
                .task {
                    if musicSource.usesLibrary { await library.load() }
                }
        }
    }
}

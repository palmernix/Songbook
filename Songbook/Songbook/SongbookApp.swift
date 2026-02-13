import SwiftUI
import SwiftData

@main
struct SongbookApp: App {
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            Group {
                switch settingsStore.persistenceMode {
                case .swiftData:
                    HomeView(settingsStore: settingsStore)
                case .iCloud:
                    iCloudTabView(settingsStore: settingsStore)
                }
            }
        }
        .modelContainer(for: Song.self)
        .environment(settingsStore)
    }
}

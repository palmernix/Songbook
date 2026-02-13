import SwiftUI
import SwiftData

@main
struct SongbookApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: Song.self) // SwiftData container
    }
}

import SwiftUI
import SwiftData
import UIKit

// MARK: - Orientation Lock

enum OrientationLock {
    private(set) static var mask: UIInterfaceOrientationMask = .allButUpsideDown

    static func lock(_ orientation: UIInterfaceOrientationMask) {
        mask = orientation
        // Request the system to re-evaluate supported orientations
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
    }

    static func unlock() {
        mask = .allButUpsideDown
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .allButUpsideDown))
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}

// MARK: - App

@main
struct SongbookApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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

//
//  SongbookApp.swift
//  Songbook
//
//  Created by Palmer Nix on 4/4/25.
//

import SwiftUI

@main
struct SongbookApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

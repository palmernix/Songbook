import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    @State private var showFolderPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Storage") {
                    Picker("Mode", selection: $settingsStore.persistenceMode) {
                        Text("In-App").tag(PersistenceMode.swiftData)
                        Text("iCloud Drive").tag(PersistenceMode.iCloud)
                    }
                    .pickerStyle(.segmented)
                }

                if settingsStore.persistenceMode == .iCloud {
                    Section("iCloud Drive Folder") {
                        if let name = settingsStore.folderName {
                            HStack {
                                Label(name, systemImage: "folder.fill")
                                Spacer()
                                Button("Change") { showFolderPicker = true }
                                    .font(.subheadline)
                            }
                        } else {
                            Button {
                                showFolderPicker = true
                            } label: {
                                Label("Select Folder", systemImage: "folder.badge.plus")
                            }
                        }

                        if settingsStore.isBookmarkStale {
                            Label("Folder access expired. Please re-select.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPickerView { url in
                    settingsStore.saveBookmark(for: url)
                }
            }
        }
    }
}

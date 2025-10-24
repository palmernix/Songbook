import SwiftUI

struct InspireOptions: Equatable {
    var style: String? = nil
    var mood: String? = nil
    var scheme: String? = nil
    var syllables: String? = nil
    var sectionKind: String? = nil

    static let empty = InspireOptions()
}

struct InspireOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var options: InspireOptions
    let onGenerate: (InspireOptions) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Style") {
                    TextField("e.g. indie folk, dream pop, hip hop", text: Binding(
                        get: { options.style ?? "" },
                        set: { options.style = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Mood") {
                    TextField("e.g. wistful, euphoric, intimate", text: Binding(
                        get: { options.mood ?? "" },
                        set: { options.mood = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Rhyme Scheme") {
                    TextField("e.g. AABB, ABAB, free verse", text: Binding(
                        get: { options.scheme ?? "" },
                        set: { options.scheme = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Target Syllables") {
                    TextField("e.g. 8–10, 10–12", text: Binding(
                        get: { options.syllables ?? "" },
                        set: { options.syllables = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.numbersAndPunctuation)
                }

                Section("Section Kind") {
                    TextField("e.g. verse, chorus, bridge", text: Binding(
                        get: { options.sectionKind ?? "" },
                        set: { options.sectionKind = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
            .navigationTitle("Inspire Options")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        onGenerate(options)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
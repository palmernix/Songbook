import SwiftUI

extension Color {
    static let warmBg = Color(red: 0.96, green: 0.95, blue: 0.93)
    static let darkInk = Color(red: 0.22, green: 0.27, blue: 0.36)
}

struct SongCard: View {
    let title: String
    let updatedAt: Date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(Color.darkInk.opacity(0.4))

            HStack(alignment: .firstTextBaseline) {
                Text(title.isEmpty ? "Untitled" : title)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text(Self.relativeDateFormatter.localizedString(
                    for: updatedAt, relativeTo: Date()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }

    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

struct FolderCard: View {
    let name: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(Color.darkInk.opacity(0.4))

            Text(name)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
}

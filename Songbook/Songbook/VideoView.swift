import SwiftUI
import AVKit

struct VideoView: View {
    @Binding var title: String
    @Binding var videoData: Data?
    var onSave: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var showCameraPicker = false
    @State private var showPhotosPicker = false
    @State private var showReplaceMenu = false
    @State private var player: AVPlayer?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.warmBg.ignoresSafeArea()

            VStack(spacing: 0) {
                titleRow

                if videoData != nil {
                    playbackView
                } else {
                    emptyState
                }

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if title.isEmpty { title = "Untitled" }
            preparePlayer()
        }
        .onDisappear { player?.pause() }
        .onChange(of: videoData) { preparePlayer() }
        .sheet(isPresented: $showCameraPicker) {
            VideoCameraPicker { data in
                videoData = data
                onSave()
            }
        }
        .sheet(isPresented: $showPhotosPicker) {
            VideoPhotosPicker { data in
                videoData = data
                onSave()
            }
        }
    }

    // MARK: - Title Row

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(Color.darkInk)

                Spacer()
            }

            TextField("Title", text: $title)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(Color.darkInk)
                .textInputAutocapitalization(.words)
                .onChange(of: title) { onSave() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "video")
                .font(.system(size: 48))
                .foregroundStyle(Color.darkInk.opacity(0.15))

            Text("No video yet")
                .font(.custom("Cochin", size: 20))
                .foregroundStyle(Color.darkInk.opacity(0.4))

            HStack(spacing: 16) {
                Button {
                    showCameraPicker = true
                } label: {
                    Label("Record", systemImage: "video.fill")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.darkInk)

                Button {
                    showPhotosPicker = true
                } label: {
                    Label("Import", systemImage: "photo.on.rectangle")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(Color.darkInk)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Playback View

    private var playbackView: some View {
        VStack(spacing: 20) {
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            Menu {
                Button {
                    player?.pause()
                    videoData = nil
                    onSave()
                    showCameraPicker = true
                } label: {
                    Label("Re-record", systemImage: "video.fill")
                }

                Button {
                    player?.pause()
                    showPhotosPicker = true
                } label: {
                    Label("Import from Photos", systemImage: "photo.on.rectangle")
                }
            } label: {
                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.medium))
            }
            .tint(Color.darkInk)
        }
    }

    // MARK: - Helpers

    private func preparePlayer() {
        guard let data = videoData else {
            player = nil
            return
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        do {
            try data.write(to: tempURL)
            player = AVPlayer(url: tempURL)
        } catch {
            player = nil
        }
    }
}

// MARK: - Video Camera Picker

private struct VideoCameraPicker: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeMedium
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data) -> Void
        init(onCapture: @escaping (Data) -> Void) { self.onCapture = onCapture }

        nonisolated func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            guard let url = info[.mediaURL] as? URL,
                  let data = try? Data(contentsOf: url) else { return }
            MainActor.assumeIsolated {
                onCapture(data)
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Video Photos Picker

private struct VideoPhotosPicker: UIViewControllerRepresentable {
    var onPick: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }

        nonisolated func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            guard let url = info[.mediaURL] as? URL,
                  let data = try? Data(contentsOf: url) else { return }
            MainActor.assumeIsolated {
                onPick(data)
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

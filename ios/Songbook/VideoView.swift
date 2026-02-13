import SwiftUI
import AVKit

// MARK: - Video Progress Bar

struct VideoProgressBar: View {
    @Binding var progress: Double
    let comments: [MediaComment]
    let duration: TimeInterval
    var onScrub: ((Double) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.darkInk.opacity(0.12))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.darkInk)
                    .frame(width: max(0, progress * geo.size.width), height: 4)

                if duration > 0 {
                    ForEach(comments) { comment in
                        let markerX = (comment.timestamp / duration) * geo.size.width
                        Circle()
                            .fill(Color.darkInk)
                            .frame(width: 8, height: 8)
                            .position(x: markerX, y: geo.size.height / 2)
                    }
                }
            }
            .frame(height: 12)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newProgress = max(0, min(1, value.location.x / geo.size.width))
                        progress = newProgress
                        onScrub?(newProgress)
                    }
            )
        }
        .frame(height: 12)
    }
}

// MARK: - Bare Player (AVPlayerLayer, no controls)

private struct BarePlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> BarePlayerUIView {
        BarePlayerUIView(player: player)
    }

    func updateUIView(_ uiView: BarePlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class BarePlayerUIView: UIView {
        let playerLayer: AVPlayerLayer

        init(player: AVPlayer) {
            playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspect
            super.init(frame: .zero)
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

// MARK: - Video View

struct VideoView: View {
    @Binding var title: String
    @Binding var videoData: Data?
    @Binding var videoComments: [MediaComment]?
    var onSave: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var showCameraPicker = false
    @State private var showPhotosPicker = false
    @State private var showReplaceMenu = false
    @State private var showAddComment = false
    @State private var newCommentText = ""
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showPlaybackOverlay = false
    @State private var playbackProgress: Double = 0
    @State private var playbackDuration: TimeInterval = 0
    @State private var videoAspectRatio: CGFloat = 16/9
    @State private var timeObserver: Any?

    @Environment(\.dismiss) private var dismiss

    private var sortedComments: [MediaComment] {
        (videoComments ?? []).sorted { $0.timestamp < $1.timestamp }
    }

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
        .onDisappear {
            removeTimeObserver()
            player?.pause()
        }
        .onChange(of: videoData) { preparePlayer() }
        .fullScreenCover(isPresented: $showCameraPicker) {
            VideoCameraPicker { data in
                videoData = data
                videoComments = nil
                onSave()
            }
            .ignoresSafeArea()
            .statusBarHidden(true)
            .onAppear { OrientationLock.lock(.portrait) }
            .onDisappear { OrientationLock.unlock() }
        }
        .sheet(isPresented: $showPhotosPicker) {
            VideoPhotosPicker { data in
                videoData = data
                videoComments = nil
                onSave()
            }
        }
        .alert("Comment at \(formatTime(playbackProgress * playbackDuration))", isPresented: $showAddComment) {
            TextField("Your note...", text: $newCommentText)
            Button("Cancel", role: .cancel) { newCommentText = "" }
            Button("Add") {
                let comment = MediaComment(
                    timestamp: playbackProgress * playbackDuration,
                    text: newCommentText
                )
                if videoComments == nil {
                    videoComments = [comment]
                } else {
                    videoComments?.append(comment)
                }
                newCommentText = ""
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
                .textInputAutocapitalization(.sentences)
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
        VStack(spacing: 0) {
            if sortedComments.isEmpty { Spacer() }

            if let player {
                BarePlayerView(player: player)
                    .aspectRatio(videoAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(showPlaybackOverlay ? 0.25 : 0))
                            .overlay {
                                if showPlaybackOverlay {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.white)
                                        .transition(.opacity)
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: showPlaybackOverlay)
                    }
                    .onTapGesture {
                        togglePlayback()
                    }
                    .padding(.horizontal, videoAspectRatio >= 1 ? 20 : 60)
                    .padding(.top, 12)
            }

            // Progress bar with markers + time labels
            VStack(spacing: 4) {
                VideoProgressBar(
                    progress: $playbackProgress,
                    comments: sortedComments,
                    duration: playbackDuration,
                    onScrub: { progress in
                        seekVideo(to: progress * playbackDuration)
                    }
                )

                HStack {
                    Text(formatTime(playbackProgress * playbackDuration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTime(playbackDuration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            // Buttons
            VStack(spacing: 12) {
                Button {
                    showAddComment = true
                } label: {
                    Label("Add Comment", systemImage: "plus.bubble")
                        .font(.subheadline.weight(.medium))
                }
                .tint(Color.darkInk)

                Menu {
                    Button {
                        player?.pause()
                        videoData = nil
                        videoComments = nil
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
            .padding(.top, 12)

            if sortedComments.isEmpty { Spacer() }

            // Comments list
            if !sortedComments.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Color.darkInk.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    HStack {
                        Text("Comments")
                            .font(.system(.caption, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.darkInk.opacity(0.4))
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    List {
                        ForEach(sortedComments) { comment in
                            commentRow(comment)
                                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                                .listRowBackground(Color.clear)
                                .listRowSeparatorTint(Color.darkInk.opacity(0.06))
                        }
                        .onDelete { offsets in
                            let sorted = sortedComments
                            for offset in offsets {
                                let id = sorted[offset].id
                                videoComments?.removeAll { $0.id == id }
                            }
                            onSave()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func commentRow(_ comment: MediaComment) -> some View {
        Button {
            seekVideo(to: comment.timestamp)
            player?.play()
            isPlaying = true
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(formatTime(comment.timestamp))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.darkInk.opacity(0.5))
                    .frame(width: 36, alignment: .leading)

                Text(comment.text)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(Color.darkInk)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                videoComments?.removeAll { $0.id == comment.id }
                onSave()
            } label: {
                Label("Delete Comment", systemImage: "trash")
            }
        }
    }

    // MARK: - Player Setup

    private func preparePlayer() {
        removeTimeObserver()
        guard let data = videoData else {
            player = nil
            return
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        do {
            try data.write(to: tempURL)
            let avPlayer = AVPlayer(url: tempURL)
            player = avPlayer

            // Get duration and aspect ratio
            let asset = avPlayer.currentItem?.asset
            Task {
                if let duration = try? await asset?.load(.duration) {
                    let seconds = CMTimeGetSeconds(duration)
                    if seconds.isFinite && seconds > 0 {
                        await MainActor.run {
                            playbackDuration = seconds
                        }
                    }
                }
                if let tracks = try? await asset?.load(.tracks) {
                    let videoTrack = tracks.first(where: { $0.mediaType == .video })
                    if let size = try? await videoTrack?.load(.naturalSize),
                       let transform = try? await videoTrack?.load(.preferredTransform) {
                        let transformed = size.applying(transform)
                        let w = abs(transformed.width)
                        let h = abs(transformed.height)
                        if w > 0 && h > 0 {
                            await MainActor.run {
                                videoAspectRatio = w / h
                            }
                        }
                    }
                }
            }

            // Periodic time observer for progress tracking
            let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
            let observer = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                guard playbackDuration > 0 else { return }
                let current = CMTimeGetSeconds(time)
                if current.isFinite {
                    playbackProgress = current / playbackDuration
                    if current >= playbackDuration - 0.1 {
                        isPlaying = false
                        showPlaybackOverlay = true
                    }
                }
            }
            timeObserver = observer
        } catch {
            player = nil
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            showPlaybackOverlay = true
        } else {
            // If at the end, restart from beginning
            if playbackProgress >= 0.99 {
                seekVideo(to: 0)
            }
            player.play()
            isPlaying = true
            showPlaybackOverlay = true
            // Hide overlay after a short delay
            Task {
                try? await Task.sleep(for: .seconds(0.6))
                showPlaybackOverlay = false
            }
        }
    }

    private func seekVideo(to timestamp: TimeInterval) {
        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        playbackProgress = playbackDuration > 0 ? timestamp / playbackDuration : 0
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Video Camera Picker

private struct VideoCameraPicker: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.cameraCaptureMode = .video
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

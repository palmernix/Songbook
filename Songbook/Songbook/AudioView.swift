import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct AudioView: View {
    @Binding var title: String
    @Binding var audioData: Data?
    var onSave: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var isRecording = false
    @State private var isPlaying = false
    @State private var recordingElapsed: TimeInterval = 0
    @State private var playbackProgress: Double = 0
    @State private var playbackDuration: TimeInterval = 0
    @State private var showDocumentPicker = false
    @State private var showReplaceMenu = false

    @State private var recorder: AVAudioRecorder?
    @State private var player: AVAudioPlayer?
    @State private var recordingTimer: Timer?
    @State private var playbackTimer: Timer?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.warmBg.ignoresSafeArea()

            VStack(spacing: 0) {
                titleRow

                if isRecording {
                    recordingView
                } else if audioData != nil {
                    playbackView
                } else {
                    emptyState
                }

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear { if title.isEmpty { title = "Untitled" } }
        .onDisappear { stopPlayback(); stopRecording() }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { data in
                audioData = data
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

            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(Color.darkInk.opacity(0.15))

            Text("No audio yet")
                .font(.custom("Cochin", size: 20))
                .foregroundStyle(Color.darkInk.opacity(0.4))

            HStack(spacing: 16) {
                Button {
                    startRecording()
                } label: {
                    Label("Record", systemImage: "mic.fill")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.darkInk)

                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Import", systemImage: "folder")
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

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            Circle()
                .fill(Color.red.opacity(0.15))
                .frame(width: 120, height: 120)
                .overlay {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                }

            Text(formatTime(recordingElapsed))
                .font(.system(.largeTitle, design: .monospaced, weight: .light))
                .foregroundStyle(Color.darkInk)

            Text("Recording...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                stopRecording()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Spacer()
        }
    }

    // MARK: - Playback View

    private var playbackView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(Color.darkInk.opacity(0.3))

            // Play/pause button
            Button {
                if isPlaying { pausePlayback() } else { startPlayback() }
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.darkInk)
            }

            // Progress
            VStack(spacing: 4) {
                ProgressView(value: playbackProgress)
                    .tint(Color.darkInk)

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
            .padding(.horizontal, 40)

            // Replace menu
            Menu {
                Button {
                    stopPlayback()
                    audioData = nil
                    onSave()
                    startRecording()
                } label: {
                    Label("Re-record", systemImage: "mic.fill")
                }

                Button {
                    stopPlayback()
                    showDocumentPicker = true
                } label: {
                    Label("Import from Files", systemImage: "folder")
                }
            } label: {
                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.medium))
            }
            .tint(Color.darkInk)

            Spacer()
        }
    }

    // MARK: - Recording

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
            try session.setActive(true)
        } catch {
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: tempURL, settings: settings)
            rec.record()
            recorder = rec
            isRecording = true
            recordingElapsed = 0

            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingElapsed = rec.currentTime
            }
            recordingTimer = timer
        } catch {
            return
        }
    }

    private func stopRecording() {
        guard let rec = recorder, isRecording else { return }
        rec.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        if let data = try? Data(contentsOf: rec.url) {
            audioData = data
            onSave()
        }

        try? FileManager.default.removeItem(at: rec.url)
        recorder = nil
    }

    // MARK: - Playback

    private func startPlayback() {
        guard let data = audioData else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }

        do {
            let p = try AVAudioPlayer(data: data)
            p.prepareToPlay()
            playbackDuration = p.duration
            p.play()
            player = p
            isPlaying = true

            let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let p = player else { return }
                if p.isPlaying {
                    playbackProgress = p.duration > 0 ? p.currentTime / p.duration : 0
                } else {
                    playbackProgress = 0
                    isPlaying = false
                    playbackTimer?.invalidate()
                    playbackTimer = nil
                }
            }
            playbackTimer = timer
        } catch {
            return
        }
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        playbackProgress = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Document Picker

private struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (Data) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }

        nonisolated func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            MainActor.assumeIsolated {
                onPick(data)
            }
        }
    }
}

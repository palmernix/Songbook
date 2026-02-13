import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Waveform View

struct WaveformView: View {
    let samples: [Float]
    @Binding var progress: Double
    var comments: [AudioComment] = []
    var duration: TimeInterval = 0
    var onScrub: ((Double) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let barCount = samples.count
            let totalSpacing = CGFloat(barCount - 1) * 1.5
            let barWidth = max(2, (geo.size.width - totalSpacing) / CGFloat(barCount))
            let midY = geo.size.height / 2

            ZStack(alignment: .top) {
                Canvas { context, size in
                    for (index, sample) in samples.enumerated() {
                        let x = CGFloat(index) * (barWidth + 1.5)
                        let amplitude = CGFloat(sample) * midY * 0.9
                        let barHeight = max(barWidth, amplitude * 2)

                        let rect = CGRect(
                            x: x,
                            y: midY - barHeight / 2,
                            width: barWidth,
                            height: barHeight
                        )

                        let progressX = progress * size.width
                        let color: Color = x + barWidth <= progressX
                            ? .darkInk
                            : .darkInk.opacity(0.2)

                        context.fill(
                            Path(roundedRect: rect, cornerRadius: barWidth / 2),
                            with: .color(color)
                        )
                    }
                }

                // Comment markers
                if duration > 0 {
                    ForEach(comments) { comment in
                        let markerX = (comment.timestamp / duration) * geo.size.width
                        Circle()
                            .fill(Color.darkInk)
                            .frame(width: 6, height: 6)
                            .position(x: markerX, y: 3)
                    }
                }
            }
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
    }
}

// MARK: - Audio View

struct AudioView: View {
    @Binding var title: String
    @Binding var audioData: Data?
    @Binding var waveformSamples: [Float]?
    @Binding var audioComments: [AudioComment]?
    var onSave: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var isRecording = false
    @State private var isPlaying = false
    @State private var recordingElapsed: TimeInterval = 0
    @State private var playbackProgress: Double = 0
    @State private var playbackDuration: TimeInterval = 0
    @State private var showDocumentPicker = false
    @State private var showReplaceMenu = false
    @State private var showAddComment = false
    @State private var newCommentText = ""

    @State private var recorder: AVAudioRecorder?
    @State private var player: AVAudioPlayer?
    @State private var recordingTimer: Timer?
    @State private var playbackTimer: Timer?

    @Environment(\.dismiss) private var dismiss

    private var sortedComments: [AudioComment] {
        (audioComments ?? []).sorted { $0.timestamp < $1.timestamp }
    }

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
        .onAppear {
            if title.isEmpty { title = "Untitled" }
            loadDuration()
        }
        .onDisappear { stopPlayback(); stopRecording() }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { data in
                audioData = data
                waveformSamples = Self.extractWaveform(from: data)
                audioComments = nil
                onSave()
            }
        }
        .alert("Comment at \(formatTime(playbackProgress * playbackDuration))", isPresented: $showAddComment) {
            TextField("Your note...", text: $newCommentText)
            Button("Cancel", role: .cancel) { newCommentText = "" }
            Button("Add") {
                let comment = AudioComment(
                    timestamp: playbackProgress * playbackDuration,
                    text: newCommentText
                )
                if audioComments == nil {
                    audioComments = [comment]
                } else {
                    audioComments?.append(comment)
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
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Spacer()

                // Play/pause button
                Button {
                    if isPlaying { pausePlayback() } else { startPlayback() }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.darkInk)
                }

                // Waveform or progress fallback
                VStack(spacing: 4) {
                    if let samples = waveformSamples, !samples.isEmpty {
                        WaveformView(
                            samples: samples,
                            progress: $playbackProgress,
                            comments: sortedComments,
                            duration: playbackDuration,
                            onScrub: { newProgress in
                                seekPlayback(to: newProgress)
                            }
                        )
                        .frame(height: 48)
                    } else {
                        ProgressView(value: playbackProgress)
                            .tint(Color.darkInk)
                    }

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

                // Add comment button
                Button {
                    showAddComment = true
                } label: {
                    Label("Add Comment", systemImage: "plus.bubble")
                        .font(.subheadline.weight(.medium))
                }
                .tint(Color.darkInk)

                // Replace menu
                Menu {
                    Button {
                        stopPlayback()
                        audioData = nil
                        waveformSamples = nil
                        audioComments = nil
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
            }

            // Comments list
            if !sortedComments.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Color.darkInk.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

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

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(sortedComments) { comment in
                                commentRow(comment)

                                if comment.id != sortedComments.last?.id {
                                    Rectangle()
                                        .fill(Color.darkInk.opacity(0.06))
                                        .frame(height: 1)
                                        .padding(.leading, 58)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func commentRow(_ comment: AudioComment) -> some View {
        Button {
            let newProgress = playbackDuration > 0 ? comment.timestamp / playbackDuration : 0
            playbackProgress = newProgress
            seekPlayback(to: newProgress)
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
                audioComments?.removeAll { $0.id == comment.id }
                onSave()
            } label: {
                Label("Delete Comment", systemImage: "trash")
            }
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
            waveformSamples = Self.extractWaveform(from: data)
            onSave()
        }

        try? FileManager.default.removeItem(at: rec.url)
        recorder = nil
    }

    // MARK: - Playback

    private func loadDuration() {
        guard let data = audioData, playbackDuration == 0 else { return }
        if let p = try? AVAudioPlayer(data: data) {
            playbackDuration = p.duration
        }
    }

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

    private func seekPlayback(to progress: Double) {
        guard let p = player else { return }
        let time = progress * p.duration
        p.currentTime = time
        if !isPlaying {
            playbackDuration = p.duration
        }
    }

    // MARK: - Waveform Extraction

    static func extractWaveform(from audioData: Data, sampleCount: Int = 80) -> [Float]? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        do {
            try audioData.write(to: tempURL)
        } catch {
            return nil
        }

        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            let file = try AVAudioFile(forReading: tempURL)
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false) else {
                return nil
            }

            let frameCount = AVAudioFrameCount(file.length)
            guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return nil
            }

            try file.read(into: buffer)

            guard let channelData = buffer.floatChannelData?[0] else {
                return nil
            }

            let totalFrames = Int(buffer.frameLength)
            let chunkSize = max(1, totalFrames / sampleCount)
            var samples: [Float] = []

            for i in 0..<sampleCount {
                let start = i * chunkSize
                let end = min(start + chunkSize, totalFrames)
                guard start < totalFrames else {
                    samples.append(0)
                    continue
                }

                var maxAmplitude: Float = 0
                for j in start..<end {
                    let amplitude = abs(channelData[j])
                    if amplitude > maxAmplitude {
                        maxAmplitude = amplitude
                    }
                }
                samples.append(maxAmplitude)
            }

            // Normalize to 0...1
            let peak = samples.max() ?? 1
            if peak > 0 {
                samples = samples.map { $0 / peak }
            }

            return samples
        } catch {
            return nil
        }
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

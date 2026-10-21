import AVFoundation
import Observation
import Speech

/// Listens to the microphone and turns speech into text, for saying answers out loud.
@MainActor
@Observable
final class SpeechRecognizer {
    enum Status: Equatable {
        case idle
        case listening
        /// The player said no to the microphone or speech recognition, or it's restricted.
        case denied
        /// Speech recognition isn't available right now (no network for server recognition, unsupported language…).
        case unavailable
    }

    private(set) var status: Status = .idle
    /// What has been heard so far in the current attempt.
    private(set) var transcript = ""

    /// Stop after this much silence once something has been heard.
    var silenceTimeout: Duration = .seconds(1.5)
    /// Never listen longer than this.
    var maxDuration: Duration = .seconds(10)

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Task<Void, Never>?
    private var maxTimer: Task<Void, Never>?
    private var onPartial: ((String) -> Bool)?
    private var onFinish: ((String) -> Void)?

    var isListening: Bool { status == .listening }

    /// Starts listening. `onPartial` sees every partial transcript and can return `true` to stop early
    /// (e.g. once it already matches the answer). `onFinish` gets the final transcript, which may be empty.
    /// `hints` are phrases the recognizer should favor, such as unusual names.
    func start(hints: [String] = [], onPartial: @escaping (String) -> Bool, onFinish: @escaping (String) -> Void) async {
        guard status != .listening else { return }
        guard await Self.requestPermissions() else {
            status = .denied
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            status = .unavailable
            return
        }

        self.onPartial = onPartial
        self.onFinish = onFinish
        transcript = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.contextualStrings = hints
            request.addsPunctuation = false
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            nonisolated(unsafe) let bufferRequest = request
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                bufferRequest.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            cleanUp()
            status = .unavailable
            return
        }

        status = .listening
        task = recognizer.recognitionTask(with: request!) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                self?.handle(text: text, isFinal: isFinal, failed: failed)
            }
        }
        maxTimer = Task { [weak self, maxDuration] in
            try? await Task.sleep(for: maxDuration)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// Stops listening and reports what was heard.
    func stop() {
        finish()
    }

    /// Stops listening without reporting anything (e.g. the screen is going away).
    func cancel() {
        guard status == .listening else { return }
        cleanUp()
        status = .idle
    }

    private func handle(text: String?, isFinal: Bool, failed: Bool) {
        guard status == .listening else { return }
        if let text, text != transcript {
            transcript = text
            if onPartial?(text) == true {
                finish()
                return
            }
            restartSilenceTimer()
        }
        if isFinal || failed {
            finish()
        }
    }

    private func restartSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self, silenceTimeout] in
            try? await Task.sleep(for: silenceTimeout)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        guard status == .listening else { return }
        let heard = transcript
        let callback = onFinish
        cleanUp()
        status = .idle
        callback?(heard)
    }

    private func cleanUp() {
        silenceTimer?.cancel()
        maxTimer?.cancel()
        silenceTimer = nil
        maxTimer = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        onPartial = nil
        onFinish = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

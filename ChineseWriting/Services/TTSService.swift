import AVFoundation

/// Wraps AVSpeechSynthesizer for Chinese character pronunciation.
@MainActor
final class TTSService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: (() -> Void)?
    /// Generation counter prevents stale delegate callbacks from firing the wrong
    /// completion. Incremented on every stop()/speak() call; delegate tasks that
    /// wake up with a mismatched generation are silently dropped.
    /// `nonisolated(unsafe)` because the didCancel delegate reads it from an
    /// arbitrary thread — safe because writes only happen on @MainActor and
    /// UInt loads are atomic on 64-bit platforms.
    nonisolated(unsafe) private var generation: UInt = 0

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    /// Speak text in Chinese.
    /// - Parameters:
    ///   - text: The text to speak, e.g. "游，旅游的游"
    ///   - traditional: If true, uses zh-TW voice; otherwise zh-CN.
    ///   - completion: Called when speech finishes.
    func speak(_ text: String, traditional: Bool = false, completion: (() -> Void)? = nil) {
        // Bump generation so any in-flight delegate Tasks from the old utterance
        // will see a stale generation and no-op.
        generation &+= 1
        self.completion = nil
        synthesizer.stopSpeaking(at: .immediate)
        activateAudioSession()
        self.completion = completion

        let utterance = AVSpeechUtterance(string: text)
        let language = traditional ? "zh-TW" : "zh-CN"
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8  // slower for learners
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.3

        synthesizer.speak(utterance)
    }

    func stop() {
        generation &+= 1
        completion = nil
        synthesizer.stopSpeaking(at: .immediate)
        deactivateAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } catch {
            print("⚠️ Audio session category setup failed: \(error)")
        }
    }

    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Deactivate audio session so other apps (music, podcasts) can resume.
    /// Called when practice ends via stop().
    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.completion?()
            self.completion = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Capture the generation at dispatch time. If speak()/stop() has been
        // called since this cancellation was triggered, generation will have
        // changed and we must not fire the (now-replaced) completion.
        let gen = self.generation
        Task { @MainActor in
            guard self.generation == gen else { return }
            // System-initiated cancellation (e.g. app backgrounded) — fire the
            // completion so callers aren't stuck waiting for a transition.
            self.completion?()
            self.completion = nil
        }
    }
}

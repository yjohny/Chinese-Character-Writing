import AVFoundation

/// Wraps AVSpeechSynthesizer for Chinese character pronunciation.
@MainActor
final class TTSService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: (() -> Void)?

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
        synthesizer.stopSpeaking(at: .immediate)
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
        synthesizer.stopSpeaking(at: .immediate)
        completion = nil
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Audio session setup failed: \(error)")
        }
    }
}

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.completion?()
            self.completion = nil
        }
    }
}

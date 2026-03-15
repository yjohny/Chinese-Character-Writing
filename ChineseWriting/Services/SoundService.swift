import AVFoundation

/// Synthesizes short sound effects using AVAudioEngine. No bundled audio files needed.
/// Does not manage the audio session — TTSService owns that lifecycle.
@MainActor
final class SoundService {
    var isEnabled: Bool = true

    enum Sound {
        case correct    // ascending two-note chime
        case incorrect  // gentle low tone
        case milestone  // arpeggio
        case dailyGoal  // bright two-note chord
    }

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var bufferCache: [Sound: AVAudioPCMBuffer] = [:]

    private let sampleRate: Double = 44100
    private let format: AVAudioFormat

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    }

    func play(_ sound: Sound) {
        guard isEnabled else { return }

        if engine == nil {
            setupEngine()
        }

        guard let engine, let playerNode else { return }

        let buffer: AVAudioPCMBuffer
        if let cached = bufferCache[sound] {
            buffer = cached
        } else {
            buffer = generateBuffer(for: sound)
            bufferCache[sound] = buffer
        }

        // Stop any currently playing sound
        playerNode.stop()

        do {
            if !engine.isRunning {
                try engine.start()
            }
            playerNode.scheduleBuffer(buffer, at: nil)
            playerNode.play()
        } catch {
            // Audio playback is non-critical — fail silently
        }
    }

    // MARK: - Private

    private func setupEngine() {
        let eng = AVAudioEngine()
        let player = AVAudioPlayerNode()

        eng.attach(player)
        eng.connect(player, to: eng.mainMixerNode, format: format)

        // Lower volume so effects don't overpower TTS
        player.volume = 0.4

        do {
            try eng.start()
        } catch {
            return
        }

        engine = eng
        playerNode = player
    }

    private func generateBuffer(for sound: Sound) -> AVAudioPCMBuffer {
        switch sound {
        case .correct:
            return generateTones(frequencies: [523, 659], noteDuration: 0.15, gap: 0.02)
        case .incorrect:
            return generateTones(frequencies: [330], noteDuration: 0.25, gap: 0)
        case .milestone:
            return generateTones(frequencies: [523, 659, 784, 1047], noteDuration: 0.12, gap: 0.02)
        case .dailyGoal:
            return generateTones(frequencies: [659, 784, 1047], noteDuration: 0.13, gap: 0.02)
        }
    }

    /// Generate a buffer with sequential sine-wave tones, each with fade-in/fade-out envelopes.
    private func generateTones(frequencies: [Double], noteDuration: Double, gap: Double) -> AVAudioPCMBuffer {
        let totalDuration = Double(frequencies.count) * noteDuration
            + Double(max(0, frequencies.count - 1)) * gap
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return buffer }

        // Zero fill
        for i in 0..<Int(frameCount) {
            channelData[i] = 0
        }

        let samplesPerNote = Int(noteDuration * sampleRate)
        let samplesPerGap = Int(gap * sampleRate)
        let fadeFrames = min(Int(0.01 * sampleRate), samplesPerNote / 4) // 10ms fade

        var offset = 0
        for freq in frequencies {
            for i in 0..<samplesPerNote {
                let t = Double(i) / sampleRate
                var sample = Float(sin(2.0 * Double.pi * freq * t))

                // Fade in
                if i < fadeFrames {
                    sample *= Float(i) / Float(fadeFrames)
                }
                // Fade out
                let remaining = samplesPerNote - 1 - i
                if remaining < fadeFrames {
                    sample *= Float(remaining) / Float(fadeFrames)
                }

                let idx = offset + i
                if idx < Int(frameCount) {
                    channelData[idx] = sample * 0.5 // amplitude
                }
            }
            offset += samplesPerNote + samplesPerGap
        }

        return buffer
    }
}

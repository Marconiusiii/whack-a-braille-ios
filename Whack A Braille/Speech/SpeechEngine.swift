import AVFoundation

@MainActor
final class SpeechEngine {

	static let shared = SpeechEngine()

	private let synthesizer = AVSpeechSynthesizer()
	private var currentVoice: AVSpeechSynthesisVoice? = AVSpeechSynthesisVoice(language: "en-US")
	private var currentRate: Float = AVSpeechUtteranceDefaultSpeechRate

	private init() {}

	func setVoice(_ voice: AVSpeechSynthesisVoice) {
		currentVoice = voice
	}

	func setRate(_ rate: Float) {
		currentRate = rate
	}

	func speak(_ text: String, interrupt: Bool = true) {
		guard !text.isEmpty else { return }

		if interrupt {
			synthesizer.stopSpeaking(at: .immediate)
		}

		let utterance = AVSpeechUtterance(string: text)
		utterance.voice = currentVoice
		utterance.rate = currentRate
		synthesizer.speak(utterance)
	}

	func cancel() {
		synthesizer.stopSpeaking(at: .immediate)
	}

	func estimatedDurationMs(for text: String) -> Int {
		let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalized.isEmpty else { return 300 }

		let words = max(1, normalized.split(whereSeparator: \.isWhitespace).count)
		let characterEstimate = Double(normalized.count) * 38.0
		let wordEstimate = Double(words) * 240.0
		let baseline = max(300.0, max(characterEstimate, wordEstimate))
		let rateScale = Double(AVSpeechUtteranceDefaultSpeechRate / max(currentRate, 0.1))

		return Int(min(max(baseline * rateScale, 300.0), 1800.0))
	}
}

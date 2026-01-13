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
		if interrupt {
			synthesizer.stopSpeaking(at: .immediate)
		}

		let utterance = AVSpeechUtterance(string: text)
		utterance.voice = currentVoice
		utterance.rate = currentRate
		utterance.rate = AVSpeechUtteranceDefaultSpeechRate

		synthesizer.speak(utterance)
	}

	func cancel() {
		synthesizer.stopSpeaking(at: .immediate)
	}
}

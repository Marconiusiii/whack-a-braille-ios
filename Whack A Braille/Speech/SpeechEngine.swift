import AVFoundation

@MainActor
final class SpeechEngine {

	static let shared = SpeechEngine()

	private let synthesizer = AVSpeechSynthesizer()

	private init() {}

	func speak(_ text: String, interrupt: Bool = true) {
		if interrupt {
			synthesizer.stopSpeaking(at: .immediate)
		}

		let utterance = AVSpeechUtterance(string: text)
		utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
		utterance.rate = AVSpeechUtteranceDefaultSpeechRate

		synthesizer.speak(utterance)
	}

	func cancel() {
		synthesizer.stopSpeaking(at: .immediate)
	}
}

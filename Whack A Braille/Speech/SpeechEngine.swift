import AVFoundation

@MainActor
final class SpeechEngine {

	static let shared = SpeechEngine()

	private let synthesizer = AVSpeechSynthesizer()
	private var currentVoice: AVSpeechSynthesisVoice?
	private var currentRate: Float = AVSpeechUtteranceDefaultSpeechRate
	private var sessionObservers: [NSObjectProtocol] = []

	private init() {
		currentVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice(language: "en-US")
		observeAudioSession()
	}

	func prewarm() {
		activateAudioSession()
	}

	deinit {
		for observer in sessionObservers {
			NotificationCenter.default.removeObserver(observer)
		}
	}

	func configure(voice: AVSpeechSynthesisVoice?, rate: Float) {
		currentVoice = voice ?? AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice(language: "en-US")
		currentRate = rate
	}

	func playVoiceSample(voice: AVSpeechSynthesisVoice?, ratePercent: Int) {
		configure(voice: voice, rate: speechRateForPercent(ratePercent))
		_ = speak("Welcome to Whack A Braille!", interrupt: true)
	}

	@discardableResult
	func speak(_ text: String, interrupt: Bool = true) -> Int {
		let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalized.isEmpty else { return 0 }

		activateAudioSession()

		if interrupt {
			synthesizer.stopSpeaking(at: .immediate)
		}

		let utterance = AVSpeechUtterance(string: normalized)
		utterance.voice = currentVoice
		utterance.rate = currentRate
		utterance.prefersAssistiveTechnologySettings = false
		synthesizer.speak(utterance)

		return estimatedDurationMs(for: normalized)
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

		return Int(min(max(baseline * rateScale, 300.0), 1_800.0))
	}

	private func activateAudioSession() {
		let session = AVAudioSession.sharedInstance()

		do {
			try session.setCategory(.playback, mode: .default, options: [.duckOthers])
			try session.setActive(true, options: [])
		} catch {
			// Keep the game usable even if the audio session cannot be updated.
		}
	}

	private func observeAudioSession() {
		let session = AVAudioSession.sharedInstance()
		let center = NotificationCenter.default

		sessionObservers.append(
			center.addObserver(
				forName: AVAudioSession.routeChangeNotification,
				object: session,
				queue: .main
			) { [weak self] _ in
				Task { @MainActor [weak self] in
					self?.activateAudioSession()
				}
			}
		)

		sessionObservers.append(
			center.addObserver(
				forName: AVAudioSession.interruptionNotification,
				object: session,
				queue: .main
			) { [weak self] notification in
				guard
					let userInfo = notification.userInfo,
					let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
					let type = AVAudioSession.InterruptionType(rawValue: typeValue)
				else {
					return
				}

				if type == .ended {
					Task { @MainActor [weak self] in
						self?.activateAudioSession()
					}
				}
			}
		)
	}

	private func speechRateForPercent(_ percent: Int) -> Float {
		let clamped = min(max(percent, 1), 100)
		let progress = Float(clamped - 1) / 99.0
		return AVSpeechUtteranceMinimumSpeechRate + ((AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * progress)
	}
}

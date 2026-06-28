import AVFoundation
import UIKit

@MainActor
final class SpeechEngine {

	static let shared = SpeechEngine()

	private var synthesizer = AVSpeechSynthesizer()
	private var currentVoice: AVSpeechSynthesisVoice?
	private var currentRate: Float = AVSpeechUtteranceDefaultSpeechRate
	private var currentVolume: Float = 0.85
	private var sessionObservers: [NSObjectProtocol] = []
	private var hasActivatedAudioSession = false

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

	func configure(voice: AVSpeechSynthesisVoice?, rate: Float, volume: Float) {
		let resolvedVoice = voice ?? AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice(language: "en-US")
		let resolvedVolume = min(max(volume, 0.0), 1.0)
		let didChange = currentVoice?.identifier != resolvedVoice?.identifier
			|| currentRate != rate
			|| currentVolume != resolvedVolume

		currentVoice = resolvedVoice
		currentRate = rate
		currentVolume = resolvedVolume

		if didChange {
			cancel()
		}
	}

	func playVoiceSample(voice: AVSpeechSynthesisVoice?, ratePercent: Int, volumePercent: Int) {
		configure(
			voice: voice,
			rate: speechRateForPercent(ratePercent),
			volume: speechVolumeForPercent(volumePercent)
		)
		_ = speak("Welcome to Whack A Braille!", interrupt: true)
	}

	@discardableResult
	func speak(_ text: String, interrupt: Bool = true) -> Int {
		let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalized.isEmpty else { return 0 }

		activateAudioSession()

		if interrupt, synthesizer.isSpeaking {
			synthesizer.stopSpeaking(at: .immediate)
		}

		let utterance = AVSpeechUtterance(string: normalized)
		utterance.voice = currentVoice
		utterance.rate = currentRate
		utterance.volume = currentVolume
		utterance.prefersAssistiveTechnologySettings = false
		synthesizer.speak(utterance)

		return estimatedDurationMs(for: normalized)
	}

	func cancel() {
		if synthesizer.isSpeaking {
			synthesizer.stopSpeaking(at: .immediate)
		}
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
		guard !hasActivatedAudioSession else { return }

		do {
			try session.setActive(true, options: [])
			hasActivatedAudioSession = true
		} catch {
			// Keep the game usable even if the audio session cannot be updated.
		}
	}

	private func recoverSpeechSystem(rebuildSynthesizer: Bool) {
		activateAudioSession()

		guard rebuildSynthesizer else { return }

		if synthesizer.isSpeaking {
			synthesizer.stopSpeaking(at: .immediate)
		}
		synthesizer = AVSpeechSynthesizer()
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
					self?.recoverSpeechSystem(rebuildSynthesizer: false)
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
						self?.hasActivatedAudioSession = false
						self?.recoverSpeechSystem(rebuildSynthesizer: true)
					}
				}
			}
		)

		sessionObservers.append(
			center.addObserver(
				forName: UIApplication.didBecomeActiveNotification,
				object: nil,
				queue: .main
			) { [weak self] _ in
				Task { @MainActor [weak self] in
					self?.hasActivatedAudioSession = false
					self?.recoverSpeechSystem(rebuildSynthesizer: true)
				}
			}
		)

		sessionObservers.append(
			center.addObserver(
				forName: UIApplication.willEnterForegroundNotification,
				object: nil,
				queue: .main
			) { [weak self] _ in
				Task { @MainActor [weak self] in
					self?.recoverSpeechSystem(rebuildSynthesizer: false)
				}
			}
		)

		sessionObservers.append(
			center.addObserver(
				forName: AVAudioSession.mediaServicesWereResetNotification,
				object: session,
				queue: .main
			) { [weak self] _ in
				Task { @MainActor [weak self] in
					self?.recoverSpeechSystem(rebuildSynthesizer: true)
				}
			}
		)
	}

	private func speechRateForPercent(_ percent: Int) -> Float {
		let clamped = min(max(percent, 1), 100)
		let progress = Float(clamped - 1) / 99.0
		return AVSpeechUtteranceMinimumSpeechRate + ((AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * progress)
	}

	private func speechVolumeForPercent(_ percent: Int) -> Float {
		let clamped = min(max(percent, 5), 100)
		return Float(clamped) / 100.0
	}
}

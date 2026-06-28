import AVFoundation
import UIKit

@MainActor
final class SpeechEngine {

	static let shared = SpeechEngine()

	private struct SpeechCacheKey: Hashable {
		let text: String
		let voiceIdentifier: String
		let rate: Float
		let volume: Float
	}

	private var synthesizer = AVSpeechSynthesizer()
	private var renderingSynthesizer = AVSpeechSynthesizer()
	private var currentVoice: AVSpeechSynthesisVoice?
	private var currentRate: Float = AVSpeechUtteranceDefaultSpeechRate
	private var currentVolume: Float = 0.85
	private var sessionObservers: [NSObjectProtocol] = []
	private var hasActivatedAudioSession = false
	private var cachedSpeechData: [SpeechCacheKey: Data] = [:]
	private var activeRenderID = UUID()
	private var isRenderingCachedSpeech = false
	private var pendingCacheCompletions: [() -> Void] = []

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
			activeRenderID = UUID()
			isRenderingCachedSpeech = false
			pendingCacheCompletions.removeAll()
			renderingSynthesizer.stopSpeaking(at: .immediate)
			cachedSpeechData.removeAll()
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

	func prepareCachedSpeech(for texts: [String], completion: @escaping () -> Void) {
		let normalizedTexts = Array(Set(texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
		guard !normalizedTexts.isEmpty else {
			completion()
			return
		}

		let keys = normalizedTexts.map(cacheKey(for:))
		let missingKeys = keys.filter { cachedSpeechData[$0] == nil }
		guard !missingKeys.isEmpty else {
			completion()
			return
		}

		pendingCacheCompletions.append(completion)
		guard !isRenderingCachedSpeech else { return }

		let renderID = UUID()
		activeRenderID = renderID
		isRenderingCachedSpeech = true
		renderCachedSpeech(keys: missingKeys, index: 0, renderID: renderID)
	}

	func cachedSpeechData(for text: String) -> Data? {
		cachedSpeechData[cacheKey(for: text.trimmingCharacters(in: .whitespacesAndNewlines))]
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
		renderingSynthesizer.stopSpeaking(at: .immediate)
		renderingSynthesizer = AVSpeechSynthesizer()
	}

	private func cacheKey(for text: String) -> SpeechCacheKey {
		SpeechCacheKey(
			text: text,
			voiceIdentifier: currentVoice?.identifier ?? "default",
			rate: currentRate,
			volume: currentVolume
		)
	}

	private func renderCachedSpeech(keys: [SpeechCacheKey], index: Int, renderID: UUID) {
		guard renderID == activeRenderID else { return }
		guard index < keys.count else {
			isRenderingCachedSpeech = false
			let completions = pendingCacheCompletions
			pendingCacheCompletions.removeAll()
			for completion in completions {
				completion()
			}
			return
		}

		let key = keys[index]
		if cachedSpeechData[key] != nil {
			renderCachedSpeech(keys: keys, index: index + 1, renderID: renderID)
			return
		}

		renderSpeechData(for: key) { [weak self] data in
			guard let self, renderID == self.activeRenderID else { return }
			if let data {
				self.cachedSpeechData[key] = data
			}
			self.renderCachedSpeech(keys: keys, index: index + 1, renderID: renderID)
		}
	}

	private func renderSpeechData(for key: SpeechCacheKey, completion: @escaping (Data?) -> Void) {
		let utterance = AVSpeechUtterance(string: key.text)
		utterance.voice = currentVoice
		utterance.rate = key.rate
		utterance.volume = key.volume
		utterance.prefersAssistiveTechnologySettings = false

		var pcm = Data()
		var sampleRate = Int(self.sampleRateFallback)
		var didFinish = false

		renderingSynthesizer.write(utterance) { [weak self] buffer in
			guard let self else { return }
			guard !didFinish else { return }

			guard let pcmBuffer = buffer as? AVAudioPCMBuffer, pcmBuffer.frameLength > 0 else {
				didFinish = true
				completion(self.makeWaveFile(fromPCM: pcm, sampleRate: sampleRate))
				return
			}

			sampleRate = Int(pcmBuffer.format.sampleRate.rounded())
			pcm.append(self.monoInt16PCMData(from: pcmBuffer))
		}
	}

	private var sampleRateFallback: Double {
		44_100.0
	}

	private func monoInt16PCMData(from buffer: AVAudioPCMBuffer) -> Data {
		let frameCount = Int(buffer.frameLength)
		let channelCount = max(1, Int(buffer.format.channelCount))
		var data = Data(capacity: frameCount * MemoryLayout<Int16>.size)

		if let floatChannels = buffer.floatChannelData {
			for frame in 0..<frameCount {
				var sample = 0.0
				for channel in 0..<channelCount {
					sample += Double(floatChannels[channel][frame])
				}
				appendInt16Sample(sample / Double(channelCount), to: &data)
			}
			return data
		}

		if let int16Channels = buffer.int16ChannelData {
			for frame in 0..<frameCount {
				var sample = 0
				for channel in 0..<channelCount {
					sample += Int(int16Channels[channel][frame])
				}
				appendRawInt16Sample(Int16(clamping: sample / channelCount), to: &data)
			}
			return data
		}

		return data
	}

	private func appendInt16Sample(_ sample: Double, to data: inout Data) {
		let clamped = max(-1.0, min(1.0, sample))
		let value = Int16(clamped * Double(Int16.max))
		appendRawInt16Sample(value, to: &data)
	}

	private func appendRawInt16Sample(_ sample: Int16, to data: inout Data) {
		var littleEndianSample = sample.littleEndian
		withUnsafeBytes(of: &littleEndianSample) { bytes in
			data.append(contentsOf: bytes)
		}
	}

	private func makeWaveFile(fromPCM pcm: Data, sampleRate: Int) -> Data? {
		guard !pcm.isEmpty else { return nil }
		let channelCount = 1
		let bitsPerSample = 16
		let byteRate = sampleRate * channelCount * bitsPerSample / 8
		let blockAlign = channelCount * bitsPerSample / 8
		let chunkSize = 36 + pcm.count

		var data = Data()
		data.append("RIFF".data(using: .ascii)!)
		data.append(UInt32(chunkSize).speechLittleEndianData)
		data.append("WAVE".data(using: .ascii)!)
		data.append("fmt ".data(using: .ascii)!)
		data.append(UInt32(16).speechLittleEndianData)
		data.append(UInt16(1).speechLittleEndianData)
		data.append(UInt16(channelCount).speechLittleEndianData)
		data.append(UInt32(sampleRate).speechLittleEndianData)
		data.append(UInt32(byteRate).speechLittleEndianData)
		data.append(UInt16(blockAlign).speechLittleEndianData)
		data.append(UInt16(bitsPerSample).speechLittleEndianData)
		data.append("data".data(using: .ascii)!)
		data.append(UInt32(pcm.count).speechLittleEndianData)
		data.append(pcm)
		return data
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

private extension FixedWidthInteger {
	var speechLittleEndianData: Data {
		var value = self.littleEndian
		return Data(bytes: &value, count: MemoryLayout<Self>.size)
	}
}

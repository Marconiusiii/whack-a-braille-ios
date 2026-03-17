import AVFoundation

final class GameAudioEngine {

	static let shared = GameAudioEngine()

	private let session = AVAudioSession.sharedInstance()

	private var timerMusicEnabled = true
	private var audioMode = "original"
	private var activePlayers: [AVAudioPlayer] = []

	private var popSoundData: Data?
	private var hitSoundData: Data?
	private var missSoundData: Data?
	private var retreatSoundData: Data?

	private init() {
		popSoundData = makeToneData(frequencies: [560, 760], duration: 0.05, volume: 0.22, fadeOut: 0.018)
		hitSoundData = makeToneData(frequencies: [820, 1080], duration: 0.07, volume: 0.28, fadeOut: 0.025)
		missSoundData = makeToneData(frequencies: [220, 180], duration: 0.09, volume: 0.2, fadeOut: 0.04)
		retreatSoundData = makeToneData(frequencies: [260, 170], duration: 0.11, volume: 0.18, fadeOut: 0.05)
	}

	func prewarm() {
		configureAudioSession()
	}

	func configure(mode: String, timerMusicEnabled: Bool) {
		self.audioMode = mode == "silly" ? "silly" : "original"
		self.timerMusicEnabled = timerMusicEnabled
		configureAudioSession()
	}

	func playOpeningCue(playEverythingIntro: Bool) {
		configureAudioSession()

		if audioMode == "silly" {
			if playEverythingIntro {
				playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.7)
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
					self.playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.7)
				}
			} else {
				playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.6)
			}
		}
	}

	func startRoundAudio(progressProvider: @escaping () -> Double, timerMusicEnabled: Bool) {
		self.timerMusicEnabled = timerMusicEnabled
		_ = progressProvider
	}

	func stopRound() {
		stopAllPlayers()
	}

	func playHit(scoreBeforeHit: Int, lane: Int) {
		_ = lane

		if audioMode == "silly" {
			playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.85)

			if scoreBeforeHit < 50, scoreBeforeHit + 10 >= 50 {
				playBundledSound(named: "50pts_2", fileExtension: "m4a", volume: 0.8)
			}
			return
		}

		playGeneratedSound(hitSoundData, volume: 1.0)
	}

	func playMiss(lane: Int) {
		_ = lane
		playGeneratedSound(missSoundData, volume: 1.0)
	}

	func playMolePop(lane: Int) {
		_ = lane
		playGeneratedSound(popSoundData, volume: 1.0)
	}

	func playRetreat(lane: Int) {
		_ = lane
		playGeneratedSound(retreatSoundData, volume: 1.0)
	}

	private func configureAudioSession() {
		do {
			try session.setCategory(.playback, mode: .default, options: [.duckOthers])
			try session.setActive(true)
		} catch {
			// Keep gameplay running even if the audio session update fails.
		}
	}

	private func playBundledSound(named name: String, fileExtension: String, volume: Float) {
		guard let url = bundledAudioURL(named: name, fileExtension: fileExtension) else { return }

		do {
			let player = try AVAudioPlayer(contentsOf: url)
			player.volume = volume
			player.prepareToPlay()
			activePlayers.append(player)
			player.play()
			purgeFinishedPlayers()
		} catch {
			// Keep gameplay running even if a bundled sound cannot be played.
		}
	}

	private func playGeneratedSound(_ data: Data?, volume: Float) {
		guard let data else { return }
		configureAudioSession()

		do {
			let player = try AVAudioPlayer(data: data)
			player.volume = volume
			player.prepareToPlay()
			activePlayers.append(player)
			player.play()
			purgeFinishedPlayers()
		} catch {
			// Keep gameplay running even if a generated sound cannot be played.
		}
	}

	private func bundledAudioURL(named name: String, fileExtension: String) -> URL? {
		let possibleURLs: [URL?] = [
			Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources/Audio"),
			Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Audio"),
			Bundle.main.url(forResource: name, withExtension: fileExtension)
		]

		return possibleURLs.compactMap { $0 }.first
	}

	private func purgeFinishedPlayers() {
		activePlayers.removeAll { !$0.isPlaying }
	}

	private func stopAllPlayers() {
		for player in activePlayers {
			player.stop()
		}
		activePlayers.removeAll()
	}

	private func makeToneData(
		frequencies: [Double],
		duration: Double,
		volume: Double,
		fadeOut: Double
	) -> Data? {
		let sampleRate = 44_100
		let frameCount = max(1, Int(duration * Double(sampleRate)))
		let fadeStartFrame = max(0, frameCount - Int(fadeOut * Double(sampleRate)))
		var pcm = Data(capacity: frameCount * MemoryLayout<Int16>.size)

		for frame in 0..<frameCount {
			let time = Double(frame) / Double(sampleRate)
			let normalizedMix = frequencies.enumerated().reduce(0.0) { partial, pair in
				let scale = pair.offset == 0 ? 1.0 : 0.55
				return partial + (sin(2.0 * .pi * pair.element * time) * scale)
			} / max(Double(frequencies.count), 1.0)

			let envelope: Double
			if frame >= fadeStartFrame {
				envelope = Double(frameCount - frame) / Double(max(frameCount - fadeStartFrame, 1))
			} else {
				envelope = 1.0
			}

			let sample = Int16(max(-1.0, min(1.0, normalizedMix * volume * envelope)) * Double(Int16.max))
			var littleEndianSample = sample.littleEndian
			pcm.append(UnsafeBufferPointer(start: &littleEndianSample, count: 1))
		}

		return makeWaveFile(fromPCM: pcm, sampleRate: sampleRate, channelCount: 1, bitsPerSample: 16)
	}

	private func makeWaveFile(fromPCM pcm: Data, sampleRate: Int, channelCount: Int, bitsPerSample: Int) -> Data {
		let byteRate = sampleRate * channelCount * bitsPerSample / 8
		let blockAlign = channelCount * bitsPerSample / 8
		let chunkSize = 36 + pcm.count

		var data = Data()
		data.append("RIFF".data(using: .ascii)!)
		data.append(UInt32(chunkSize).littleEndianData)
		data.append("WAVE".data(using: .ascii)!)
		data.append("fmt ".data(using: .ascii)!)
		data.append(UInt32(16).littleEndianData)
		data.append(UInt16(1).littleEndianData)
		data.append(UInt16(channelCount).littleEndianData)
		data.append(UInt32(sampleRate).littleEndianData)
		data.append(UInt32(byteRate).littleEndianData)
		data.append(UInt16(blockAlign).littleEndianData)
		data.append(UInt16(bitsPerSample).littleEndianData)
		data.append("data".data(using: .ascii)!)
		data.append(UInt32(pcm.count).littleEndianData)
		data.append(pcm)
		return data
	}
}

private extension FixedWidthInteger {
	var littleEndianData: Data {
		var value = self.littleEndian
		return Data(bytes: &value, count: MemoryLayout<Self>.size)
	}
}

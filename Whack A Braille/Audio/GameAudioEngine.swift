import AVFoundation

final class GameAudioEngine {

	static let shared = GameAudioEngine()

	private let session = AVAudioSession.sharedInstance()
	private let lanePanMap: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
	private let sampleRate = 44_100.0

	private var timerMusicEnabled = true
	private var audioMode = "original"
	private var activePlayers: [AVAudioPlayer] = []
	private var hasStartedPrewarm = false
	private var hasFinishedPrewarm = false

	private lazy var popSoundData: Data? = makePopSoundData()
	private lazy var hitSoundData: Data? = makeHitSoundData()
	private lazy var missSoundData: Data? = makeMissSoundData()
	private lazy var retreatSoundData: Data? = makeRetreatSoundData()
	private lazy var openingCueData: Data? = makeStartFlourishData()
	private lazy var everythingCueData: Data? = makeEverythingStingerData()
	private lazy var endCueData: Data? = makeEndCueData()

	private init() {}

	func prewarm() {
		configureAudioSession()
		guard !hasStartedPrewarm else { return }
		hasStartedPrewarm = true

		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			guard let self else { return }
			_ = self.popSoundData
			_ = self.hitSoundData
			_ = self.missSoundData
			_ = self.retreatSoundData
			_ = self.openingCueData
			_ = self.everythingCueData
			_ = self.endCueData

			DispatchQueue.main.async {
				self.hasFinishedPrewarm = true
			}
		}
	}

	var isReadyForGameplay: Bool {
		hasFinishedPrewarm
	}

	func configure(mode: String, timerMusicEnabled: Bool) {
		audioMode = mode == "silly" ? "silly" : "original"
		self.timerMusicEnabled = timerMusicEnabled
		configureAudioSession()
	}

	func playOpeningCue(playEverythingIntro: Bool) {
		if audioMode == "silly" {
			if playEverythingIntro {
				playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.7, pan: 0)
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
					self.playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.7, pan: 0)
				}
			} else {
				playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.6, pan: 0)
			}
			return
		}

		playGeneratedSound(playEverythingIntro ? everythingCueData : openingCueData, volume: 1.0, pan: 0)
	}

	func playEndCue() {
		if audioMode == "silly" {
			playBundledSound(named: "50pts_2", fileExtension: "m4a", volume: 0.85, pan: 0)
			return
		}

		playGeneratedSound(endCueData, volume: 1.0, pan: 0)
	}

	func startRoundAudio(progressProvider: @escaping () -> Double, timerMusicEnabled: Bool) {
		self.timerMusicEnabled = timerMusicEnabled
		_ = progressProvider
	}

	func stopRound() {
		stopAllPlayers()
	}

	func playHit(scoreBeforeHit: Int, lane: Int) {
		let pan = pan(for: lane)

		if audioMode == "silly" {
			playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.85, pan: pan)

			if scoreBeforeHit < 50, scoreBeforeHit + 10 >= 50 {
				playBundledSound(named: "50pts_2", fileExtension: "m4a", volume: 0.8, pan: 0)
			}
			return
		}

		playGeneratedSound(hitSoundData, volume: 1.18, pan: pan)
	}

	func playMiss(lane: Int) {
		playGeneratedSound(missSoundData, volume: 0.72, pan: pan(for: lane))
	}

	func playMolePop(lane: Int) {
		playGeneratedSound(popSoundData, volume: 0.45, pan: pan(for: lane))
	}

	func playRetreat(lane: Int) {
		playGeneratedSound(retreatSoundData, volume: 1.0, pan: pan(for: lane))
	}

	private func pan(for lane: Int) -> Float {
		guard lanePanMap.indices.contains(lane) else { return 0 }
		return lanePanMap[lane]
	}

	private func configureAudioSession() {
		do {
			try session.setCategory(.playback, mode: .default, options: [.duckOthers])
			try session.setActive(true)
		} catch {
			// Keep gameplay running even if audio session activation fails.
		}
	}

	private func playBundledSound(named name: String, fileExtension: String, volume: Float, pan: Float) {
		guard let url = bundledAudioURL(named: name, fileExtension: fileExtension) else { return }

		do {
			let player = try AVAudioPlayer(contentsOf: url)
			player.volume = volume
			player.pan = pan
			player.prepareToPlay()
			activePlayers.append(player)
			player.play()
			purgeFinishedPlayers()
		} catch {
			// Keep gameplay running even if a bundled sound cannot be played.
		}
	}

	private func playGeneratedSound(_ data: Data?, volume: Float, pan: Float) {
		guard let data, data.count > 44 else { return }

		do {
			let player = try AVAudioPlayer(data: data)
			guard player.duration > 0 else { return }
			player.volume = volume
			player.pan = pan
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

	private func makeHitSoundData() -> Data? {
		makeWaveFile(duration: 0.9) { time in
			let sub = envelope(time, attack: 0.015, release: 0.14, peak: 1.15) *
				sine(lerpExp(start: 75, end: 45, progress: min(time / 0.09, 1)), time)

			let subHarm = envelope(time, attack: 0.02, release: 0.16, peak: 0.28) *
				triangle(lerpExp(start: 110, end: 80, progress: min(time / 0.10, 1)), time)

			let body = envelope(time, attack: 0.02, release: 0.19, peak: 0.7) *
				triangle(lerpExp(start: 145, end: 95, progress: min(time / 0.11, 1)), time)

			let noiseEnv = envelope(time, attack: 0.01, release: 0.08, peak: 0.22)
			let noise = noiseEnv * filteredNoise(seed: 23_517, time: time, carrier: 540)

			let springStart = 0.04
			let spring = springTone(
				time: max(0, time - springStart),
				base: 195,
				duration: 0.85,
				peakGain: 0.4
			)

			return clampSample((sub + subHarm + body + noise + spring) * 0.48)
		}
	}

	private func makeMissSoundData() -> Data? {
		let duration = 0.32
		return makeWaveFile(duration: duration) { time in
			let progress = min(max(time / duration, 0), 1)
			let noise = filteredNoise(seed: 7_331, time: time, carrier: lerp(start: 620, end: 280, progress: progress))
			let air = triangle(lerp(start: 520, end: 260, progress: progress), time) * 0.08
			let env = envelope(time, attack: 0.03, release: duration, peak: 0.55)
			return clampSample((noise * 0.26 + air) * env * 0.58)
		}
	}

	private func makePopSoundData() -> Data? {
		let duration = 0.3
		return makeWaveFile(duration: duration) { time in
			let progress = min(max(time / 0.22, 0), 1)
			let vibrato = sin(2 * .pi * 5.2 * time) * 10
			let freq = lerpExp(start: 155, end: 520, progress: progress) + vibrato
			let body = sine(freq, time)
			let support = triangle(max(freq * 0.5, 1), time) * 0.18
			let env = linearEnvelope(time, attack: 0.022, release: 0.27, peak: 0.48)
			return clampSample((body * 0.26 + support) * env)
		}
	}

	private func makeRetreatSoundData() -> Data? {
		let duration = 0.2
		return makeWaveFile(duration: duration) { time in
			let progress = min(max(time / 0.14, 0), 1)
			let vibrato = sin(2 * .pi * 16 * time) * 32
			let freq = lerpExp(start: 680, end: 190, progress: progress) + vibrato
			let body = sine(freq, time)
			let env = linearEnvelope(time, attack: 0.02, release: 0.18, peak: 0.55)
			return clampSample(body * env * 0.42)
		}
	}

	private func makeStartFlourishData() -> Data? {
		let beat = 60.0 / 220.0
		let rootChord = [261.63, 329.63, 392.0]
		let resolveChord = rootChord.map { $0 * 1.5 }
		let duration = beat * 6.0

		return makeWaveFile(duration: duration) { time in
			var sample = 0.0
			sample += chordBurst(time: time, start: 0, duration: beat, frequencies: rootChord, peak: 0.65)
			sample += chordBurst(time: time, start: beat * 1.4, duration: beat, frequencies: rootChord, peak: 0.6)
			sample += sustainedChord(
				time: time,
				start: beat * 2.0,
				duration: beat * 4.0,
				frequencies: resolveChord,
				peak: 0.75,
				vibratoRate: 4.6,
				vibratoDepth: 3.2
			)
			return clampSample(sample * 0.45)
		}
	}

	private func makeEverythingStingerData() -> Data? {
		let beat = 60.0 / 220.0
		let rootChord = [261.63, 311.13, 392.0]
		let trillStart = beat * 0.9
		let trillDuration = beat * 1.2
		let sustainStart = trillStart + trillDuration * 0.8
		let duration = sustainStart + beat * 4.0

		return makeWaveFile(duration: duration) { time in
			var sample = 0.0
			sample += chordBurst(time: time, start: 0, duration: beat, frequencies: rootChord, peak: 0.7)

			if time >= trillStart, time <= trillStart + trillDuration {
				let local = time - trillStart
				let freq = local.remainder(dividingBy: 0.1) < 0.05 ? rootChord[0] : rootChord[0] * 1.05946
				let env = envelope(local, attack: 0.04, release: trillDuration, peak: 0.6)
				sample += triangle(freq, local) * env
			}

			sample += sustainedChord(
				time: time,
				start: sustainStart,
				duration: beat * 4.0,
				frequencies: rootChord,
				peak: 0.8,
				vibratoRate: 3.5,
				vibratoDepth: 10.5
			)

			return clampSample(sample * 0.5)
		}
	}

	private func makeEndCueData() -> Data? {
		let beat = 60.0 / 180.0
		let progression: [([Double], Double, Double)] = [
			([261.63, 329.63, 392.0], 130.81, beat),
			([261.63, 392.0, 523.25], 130.81, beat),
			([277.18, 329.63, 392.0], 138.59, beat),
			([293.66, 369.99, 440.0], 146.83, beat),
			([196.0, 246.94, 392.0, 493.88], 98.0, beat * 4.0)
		]

		let totalDuration = progression.reduce(0.0) { $0 + $1.2 }

		return makeWaveFile(duration: totalDuration) { time in
			var sample = 0.0
			var cursor = 0.0

			for (index, step) in progression.enumerated() {
				let chord = step.0
				let bass = step.1
				let stepDuration = step.2

				if time >= cursor, time <= cursor + stepDuration {
					sample += chordBurst(
						time: time,
						start: cursor,
						duration: stepDuration,
						frequencies: chord,
						peak: 0.9,
						vibratoRate: index == progression.count - 1 ? 3.8 : nil,
						vibratoDepth: index == progression.count - 1 ? 2.2 : nil
					)

					let local = time - cursor
					let bassEnv = envelope(local, attack: 0.05, release: stepDuration, peak: 0.6)
					sample += sine(bass, local) * bassEnv
				}

				cursor += stepDuration
			}

			return clampSample(sample * 0.45)
		}
	}

	private func makeWaveFile(duration: Double, sample: (Double) -> Double) -> Data? {
		let frameCount = max(1, Int(duration * sampleRate))
		var pcm = Data(capacity: frameCount * MemoryLayout<Int16>.size)

		for frame in 0..<frameCount {
			let time = Double(frame) / sampleRate
			let value = Int16(clampSample(sample(time)) * Double(Int16.max))
			var littleEndianSample = value.littleEndian
			withUnsafeBytes(of: &littleEndianSample) { bytes in
				pcm.append(contentsOf: bytes)
			}
		}

		return makeWaveFile(fromPCM: pcm, sampleRate: Int(sampleRate), channelCount: 1, bitsPerSample: 16)
	}

	private func makeWaveFile(fromPCM pcm: Data, sampleRate: Int, channelCount: Int, bitsPerSample: Int) -> Data? {
		guard !pcm.isEmpty else { return nil }
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

	private func chordBurst(
		time: Double,
		start: Double,
		duration: Double,
		frequencies: [Double],
		peak: Double,
		vibratoRate: Double? = nil,
		vibratoDepth: Double? = nil
	) -> Double {
		guard time >= start, time <= start + duration else { return 0 }
		let local = time - start
		let env = envelope(local, attack: 0.05, release: duration, peak: peak)

		return frequencies.reduce(0.0) { partial, frequency in
			let vibrato = (vibratoRate != nil && vibratoDepth != nil) ? sin(2 * .pi * vibratoRate! * local) * vibratoDepth! : 0
			return partial + (triangle(frequency + vibrato, local) * env / Double(frequencies.count))
		}
	}

	private func sustainedChord(
		time: Double,
		start: Double,
		duration: Double,
		frequencies: [Double],
		peak: Double,
		vibratoRate: Double,
		vibratoDepth: Double
	) -> Double {
		guard time >= start, time <= start + duration else { return 0 }
		let local = time - start
		let env = envelope(local, attack: 0.08, release: duration, peak: peak)

		return frequencies.reduce(0.0) { partial, frequency in
			let vibrato = sin(2 * .pi * vibratoRate * local) * vibratoDepth
			return partial + (triangle(frequency + vibrato, local) * env / Double(frequencies.count))
		}
	}

	private func springTone(time: Double, base: Double, duration: Double, peakGain: Double) -> Double {
		guard time > 0, time < duration else { return 0 }

		let freq: Double
		if time < 0.14 {
			freq = lerpExp(start: base * 0.78, end: base * 1.25, progress: time / 0.14)
		} else if time < 0.32 {
			freq = lerpExp(start: base * 1.25, end: base * 0.78, progress: (time - 0.14) / 0.18)
		} else if time < 0.51 {
			freq = lerpExp(start: base * 0.78, end: base * 1.08, progress: (time - 0.32) / 0.19)
		} else {
			freq = lerpExp(start: base * 1.08, end: base, progress: min((time - 0.51) / (duration - 0.51), 1))
		}

		let wobbleDepth = lerpExp(start: 15, end: 2.5, progress: min(time / duration, 1))
		let vibrato = sin(2 * .pi * 3.0 * time) * wobbleDepth
		let env = envelope(time, attack: 0.04, release: duration, peak: peakGain)
		return triangle(freq + vibrato, time) * env
	}

	private func filteredNoise(seed: UInt64, time: Double, carrier: Double) -> Double {
		let noise = pseudoNoise(seed: seed, index: Int(time * sampleRate))
		let color = sin(2 * .pi * carrier * time) * 0.65 + sin(2 * .pi * (carrier * 0.5) * time) * 0.35
		return noise * color
	}

	private func envelope(_ time: Double, attack: Double, release: Double, peak: Double) -> Double {
		guard time >= 0, time <= release else { return 0 }
		if time <= attack {
			return max(0.0001, peak * (time / max(attack, 0.0001)))
		}

		let tailProgress = (time - attack) / max(release - attack, 0.0001)
		return max(0.0001, peak * pow(0.0001 / peak, tailProgress))
	}

	private func linearEnvelope(_ time: Double, attack: Double, release: Double, peak: Double) -> Double {
		guard time >= 0, time <= release else { return 0 }
		if time <= attack {
			return peak * (time / max(attack, 0.0001))
		}

		let remaining = max(release - time, 0)
		return peak * (remaining / max(release - attack, 0.0001))
	}

	private func triangle(_ frequency: Double, _ time: Double) -> Double {
		guard frequency > 0 else { return 0 }
		let phase = (time * frequency).truncatingRemainder(dividingBy: 1.0)
		return 1.0 - 4.0 * abs(phase - 0.5)
	}

	private func sine(_ frequency: Double, _ time: Double) -> Double {
		sin(2.0 * .pi * frequency * time)
	}

	private func pseudoNoise(seed: UInt64, index: Int) -> Double {
		var x = UInt64(index &* 1_103_515_245) &+ seed &+ 12_345
		x ^= (x << 13)
		x ^= (x >> 7)
		x ^= (x << 17)
		let normalized = Double(x & 0xffff) / Double(UInt16.max)
		return normalized * 2.0 - 1.0
	}

	private func clampSample(_ value: Double) -> Double {
		max(-1.0, min(1.0, value))
	}

	private func lerp(start: Double, end: Double, progress: Double) -> Double {
		start + ((end - start) * progress)
	}

	private func lerpExp(start: Double, end: Double, progress: Double) -> Double {
		guard start > 0, end > 0 else { return lerp(start: start, end: end, progress: progress) }
		return start * pow(end / start, progress)
	}
}

private extension FixedWidthInteger {
	var littleEndianData: Data {
		var value = self.littleEndian
		return Data(bytes: &value, count: MemoryLayout<Self>.size)
	}
}

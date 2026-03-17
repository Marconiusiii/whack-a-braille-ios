import AVFoundation

final class GameAudioEngine {

	static let shared = GameAudioEngine()

	private let engine = AVAudioEngine()
	private let session = AVAudioSession.sharedInstance()
	private let sampleRate = 44_100.0
	private let molePanMap: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0]

	private var beatGeneration: Int = 0
	private var beatStep: Int = 0
	private var progressProvider: (() -> Double)?
	private var hasPlayedStartFlourish: Bool = false

	private init() {
		configureAudioSession()
		startEngineIfNeeded()
	}

	func startRound(progressProvider: @escaping () -> Double) {
		self.progressProvider = progressProvider
		hasPlayedStartFlourish = false
		playStartFlourish()
		startRoundBeat()
	}

	func stopRound() {
		beatGeneration += 1
		beatStep = 0
		progressProvider = nil
	}

	func playHit(scoreBeforeHit: Int, lane: Int) {
		startEngineIfNeeded()

		let lanePan = pan(for: lane)
		let frequency = 660.0 + Double(lane) * 35.0
		let buffer = makeToneBuffer(
			duration: 0.12,
			attack: 0.002,
			release: 0.10
		) { time in
			let shimmer = sin(2.0 * .pi * (frequency * 1.5) * time) * 0.18
			let tone = triangleWave(frequency: frequency, time: time) * 0.72
			return tone + shimmer
		}

		play(buffer: buffer, pan: lanePan, volume: 0.95)

		if scoreBeforeHit < 50 && scoreBeforeHit + 10 >= 50 {
			playFiftyPointAccent()
		}
	}

	func playMiss(lane: Int) {
		startEngineIfNeeded()

		let lanePan = pan(for: lane)
		let buffer = makeToneBuffer(
			duration: 0.18,
			attack: 0.002,
			release: 0.16
		) { time in
			let downward = max(180.0, 300.0 - (time * 520.0))
			return sineWave(frequency: downward, time: time) * 0.6
		}

		play(buffer: buffer, pan: lanePan, volume: 0.7)
	}

	func playMolePop(lane: Int) {
		startEngineIfNeeded()

		let lanePan = pan(for: lane)
		let buffer = makeToneBuffer(
			duration: 0.08,
			attack: 0.001,
			release: 0.06
		) { time in
			let pop = sineWave(frequency: 220.0 + Double(lane) * 28.0, time: time) * 0.35
			let click = noise(time: time) * 0.12
			return pop + click
		}

		play(buffer: buffer, pan: lanePan, volume: 0.55)
	}

	func playRetreat(lane: Int) {
		startEngineIfNeeded()

		let lanePan = pan(for: lane)
		let buffer = makeToneBuffer(
			duration: 0.18,
			attack: 0.001,
			release: 0.17
		) { time in
			let fall = max(120.0, 320.0 - (time * 900.0))
			let tone = sineWave(frequency: fall, time: time) * 0.34
			let dust = noise(time: time) * 0.08
			return tone + dust
		}

		play(buffer: buffer, pan: lanePan, volume: 0.45)
	}

	private func startRoundBeat() {
		beatGeneration += 1
		beatStep = 0

		let generation = beatGeneration
		scheduleNextBeat(generation: generation)
	}

	private func scheduleNextBeat(generation: Int) {
		guard generation == beatGeneration else { return }

		let interval = currentBeatInterval()
		DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
			guard let self else { return }
			guard generation == self.beatGeneration else { return }

			self.playBeat(step: self.beatStep)
			self.beatStep = (self.beatStep + 1) % 4
			self.scheduleNextBeat(generation: generation)
		}
	}

	private func currentBeatInterval() -> TimeInterval {
		let progress = progressProvider?() ?? 0
		let start = 0.68
		let end = 0.26
		return start + ((end - start) * progress)
	}

	private func playBeat(step: Int) {
		startEngineIfNeeded()

		let progress = progressProvider?() ?? 0
		let root = 110.0 + (progress * 60.0)
		let frequency: Double

		switch step {
		case 0:
			frequency = root
		case 1:
			frequency = root * 1.25
		case 2:
			frequency = root * 1.5
		default:
			frequency = root * 1.25
		}

		let duration = max(0.08, currentBeatInterval() * 0.7)
		let buffer = makeToneBuffer(
			duration: duration,
			attack: 0.002,
			release: duration * 0.8
		) { time in
			let base = triangleWave(frequency: frequency, time: time) * 0.16
			let overtone = sineWave(frequency: frequency * 2.0, time: time) * 0.04
			return base + overtone
		}

		play(buffer: buffer, pan: 0.0, volume: 0.35)
	}

	private func playStartFlourish() {
		guard !hasPlayedStartFlourish else { return }

		hasPlayedStartFlourish = true
		startEngineIfNeeded()

		let chord = [261.63, 329.63, 392.0]
		let resolve = [392.0, 493.88, 587.33]

		playChord(chord, at: 0.0, duration: 0.18, volume: 0.36)
		playChord(chord, at: 0.19, duration: 0.18, volume: 0.34)
		playChord(resolve, at: 0.42, duration: 0.42, volume: 0.30)
	}

	private func playFiftyPointAccent() {
		let frequencies = [523.25, 659.25, 783.99]
		playChord(frequencies, at: 0.0, duration: 0.28, volume: 0.42)
	}

	private func playChord(_ frequencies: [Double], at delay: TimeInterval, duration: TimeInterval, volume: Float) {
		for frequency in frequencies {
			let buffer = makeToneBuffer(
				duration: duration,
				attack: 0.003,
				release: duration * 0.82
			) { time in
				triangleWave(frequency: frequency, time: time) * 0.24
			}

			play(buffer: buffer, pan: 0.0, volume: volume, delay: delay)
		}
	}

	private func play(
		buffer: AVAudioPCMBuffer,
		pan: Float,
		volume: Float,
		delay: TimeInterval = 0
	) {
		let performPlay = { [weak self] in
			guard let self else { return }

			let node = AVAudioPlayerNode()
			node.pan = pan
			node.volume = volume

			self.engine.attach(node)
			self.engine.connect(node, to: self.engine.mainMixerNode, format: buffer.format)
			self.startEngineIfNeeded()

			node.scheduleBuffer(buffer, at: nil, options: []) { [weak self, weak node] in
				guard let self, let node else { return }
				DispatchQueue.main.async {
					node.stop()
					self.engine.detach(node)
				}
			}

			node.play()
		}

		if delay > 0 {
			DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: performPlay)
		} else {
			performPlay()
		}
	}

	private func configureAudioSession() {
		do {
			try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
			try session.setActive(true)
		} catch {
			// Keep the game playable even if session setup is denied.
		}
	}

	private func startEngineIfNeeded() {
		guard !engine.isRunning else { return }

		do {
			try engine.start()
		} catch {
			// If startup fails, stop trying to schedule audio for this action.
		}
	}

	private func pan(for lane: Int) -> Float {
		guard molePanMap.indices.contains(lane) else { return 0 }
		return molePanMap[lane]
	}

	private func makeToneBuffer(
		duration: TimeInterval,
		attack: TimeInterval,
		release: TimeInterval,
		sample: (Double) -> Double
	) -> AVAudioPCMBuffer {
		let frameCount = max(1, AVAudioFrameCount(duration * sampleRate))
		let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
		let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
		buffer.frameLength = frameCount

		let samples = buffer.floatChannelData![0]

		for frame in 0..<Int(frameCount) {
			let time = Double(frame) / sampleRate
			let attackEnvelope = attack > 0 ? min(1.0, time / attack) : 1.0
			let releaseStart = max(0.0, duration - release)
			let releaseEnvelope: Double

			if time < releaseStart || release <= 0 {
				releaseEnvelope = 1.0
			} else {
				releaseEnvelope = max(0.0, 1.0 - ((time - releaseStart) / release))
			}

			let envelope = min(attackEnvelope, 1.0) * releaseEnvelope
			samples[frame] = Float(sample(time) * envelope)
		}

		return buffer
	}

	private func sineWave(frequency: Double, time: Double) -> Double {
		sin(2.0 * .pi * frequency * time)
	}

	private func triangleWave(frequency: Double, time: Double) -> Double {
		let phase = (time * frequency).truncatingRemainder(dividingBy: 1.0)
		return (4.0 * abs(phase - 0.5)) - 1.0
	}

	private func noise(time: Double) -> Double {
		let seed = sin((time + 1.0) * 12_345.6789) * 43_758.5453
		return (seed - floor(seed)) * 2.0 - 1.0
	}
}

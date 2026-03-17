import AVFoundation

final class GameAudioEngine {

static let shared = GameAudioEngine()

	private let engine = AVAudioEngine()
	private let session = AVAudioSession.sharedInstance()
	private let sampleRate = 44_100.0
	private let molePanMap: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0]

	private var beatGeneration = 0
	private var beatStep = 0
	private var progressProvider: (() -> Double)?
	private var timerMusicEnabled = true
	private var audioMode = "original"

	private var popBuffer: AVAudioPCMBuffer?
	private var retreatBuffer: AVAudioPCMBuffer?
	private var beatLowBuffer: AVAudioPCMBuffer?
	private var beatHighBuffer: AVAudioPCMBuffer?
	private var hitBuffers: [Int: AVAudioPCMBuffer] = [:]
	private var missBuffers: [Int: AVAudioPCMBuffer] = [:]
	private var startBuffers: [AVAudioPCMBuffer] = []
	private var everythingBuffers: [AVAudioPCMBuffer] = []
	private var sillyHitBuffer: AVAudioPCMBuffer?
	private var fiftyPointBuffer: AVAudioPCMBuffer?

	private init() {
		configureAudioSession()
		buildOriginalBuffers()
		loadBundledAudio()
		startEngineIfNeeded()
	}

	func prewarm() {
		configureAudioSession()
		startEngineIfNeeded()
	}

	func configure(mode: String, timerMusicEnabled: Bool) {
		self.audioMode = mode == "silly" ? "silly" : "original"
		self.timerMusicEnabled = timerMusicEnabled
		configureAudioSession()
		startEngineIfNeeded()
	}

	func startRound(progressProvider: @escaping () -> Double, playEverythingIntro: Bool) {
		self.progressProvider = progressProvider

		if playEverythingIntro {
			playEverythingStingerIfNeeded()
		} else {
			playStartFlourish()
		}

		if timerMusicEnabled {
			startRoundBeat()
		}
	}

	func stopRound() {
		beatGeneration += 1
		beatStep = 0
		progressProvider = nil
	}

	func playHit(scoreBeforeHit: Int, lane: Int) {
		if audioMode == "silly", let sillyHitBuffer {
			play(buffer: sillyHitBuffer, pan: pan(for: lane), volume: 0.85, rate: Float(0.9 + Double.random(in: 0...0.2)))
			if scoreBeforeHit < 50, scoreBeforeHit + 10 >= 50, let fiftyPointBuffer {
				play(buffer: fiftyPointBuffer, pan: 0, volume: 0.8)
			}
			return
		}

		if let buffer = hitBuffers[lane] ?? hitBuffers[0] {
			play(buffer: buffer, pan: pan(for: lane), volume: 0.95)
		}
	}

	func playMiss(lane: Int) {
		if let buffer = missBuffers[lane] ?? missBuffers[0] {
			play(buffer: buffer, pan: pan(for: lane), volume: 0.8)
		}
	}

	func playMolePop(lane: Int) {
		if let popBuffer {
			play(buffer: popBuffer, pan: pan(for: lane), volume: 0.65)
		}
	}

	func playRetreat(lane: Int) {
		if let retreatBuffer {
			play(buffer: retreatBuffer, pan: pan(for: lane), volume: 0.55)
		}
	}

	private func playEverythingStingerIfNeeded() {
		guard !everythingBuffers.isEmpty else {
			playStartFlourish()
			return
		}

		for (index, buffer) in everythingBuffers.enumerated() {
			play(buffer: buffer, pan: 0, volume: 0.35, delay: Double(index) * 0.12)
		}
	}

	private func playStartFlourish() {
		guard !startBuffers.isEmpty else { return }

		for (index, buffer) in startBuffers.enumerated() {
			let delay: Double
			switch index {
			case 0:
				delay = 0
			case 1:
				delay = 0.19
			default:
				delay = 0.42
			}
			play(buffer: buffer, pan: 0, volume: 0.38, delay: delay)
		}
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

	private func playBeat(step: Int) {
		let useHigh = step == 1 || step == 3
		let buffer = useHigh ? beatHighBuffer : beatLowBuffer
		guard let buffer else { return }
		play(buffer: buffer, pan: 0, volume: 0.28)
	}

	private func currentBeatInterval() -> TimeInterval {
		let progress = progressProvider?() ?? 0
		let start = 0.68
		let end = 0.26
		return start + ((end - start) * progress)
	}

	private func pan(for lane: Int) -> Float {
		guard molePanMap.indices.contains(lane) else { return 0 }
		return molePanMap[lane]
	}

	private func play(
		buffer: AVAudioPCMBuffer,
		pan: Float,
		volume: Float,
		delay: TimeInterval = 0,
		rate: Float = 1.0
	) {
		let performPlay = { [weak self] in
			guard let self else { return }
			self.configureAudioSession()
			self.startEngineIfNeeded()

			let player = AVAudioPlayerNode()
			self.engine.attach(player)

			let format = buffer.format

			if rate == 1.0 {
				self.engine.connect(player, to: self.engine.mainMixerNode, format: format)
				player.pan = pan
				player.volume = volume
				player.scheduleBuffer(buffer, completionHandler: { [weak self, weak player] in
					guard let self, let player else { return }
					DispatchQueue.main.async {
						player.stop()
						self.engine.detach(player)
					}
				})
			} else {
				let varispeed = AVAudioUnitVarispeed()
				varispeed.rate = rate
				self.engine.attach(varispeed)
				self.engine.connect(player, to: varispeed, format: format)
				self.engine.connect(varispeed, to: self.engine.mainMixerNode, format: format)
				player.pan = pan
				player.volume = volume
				player.scheduleBuffer(buffer, completionHandler: { [weak self, weak player, weak varispeed] in
					guard let self, let player else { return }
					DispatchQueue.main.async {
						player.stop()
						self.engine.detach(player)
						if let varispeed {
							self.engine.detach(varispeed)
						}
					}
				})
			}

			player.play()
		}

		if delay > 0 {
			DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: performPlay)
		} else {
			performPlay()
		}
	}

	private func configureAudioSession() {
		do {
			try session.setCategory(.playback, mode: .default, options: [.duckOthers])
			try session.setActive(true)
		} catch {
			// Keep gameplay running even if the session update fails.
		}
	}

	private func startEngineIfNeeded() {
		guard !engine.isRunning else { return }

		do {
			try engine.start()
		} catch {
			// Audio will fail silently if the engine cannot start.
		}
	}

	private func loadBundledAudio() {
		sillyHitBuffer = loadBuffer(named: "ChanceyBonk_6", extension: "m4a")
		fiftyPointBuffer = loadBuffer(named: "50pts_2", extension: "m4a")
	}

	private func loadBuffer(named name: String, extension fileExtension: String) -> AVAudioPCMBuffer? {
		let possibleURLs: [URL?] = [
			Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources/Audio"),
			Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Audio"),
			Bundle.main.url(forResource: name, withExtension: fileExtension)
		]

		guard let url = possibleURLs.compactMap({ $0 }).first else { return nil }

		do {
			let file = try AVAudioFile(forReading: url)
			let format = file.processingFormat
			let frameCount = AVAudioFrameCount(file.length)
			let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
			try file.read(into: buffer!)
			return buffer
		} catch {
			return nil
		}
	}

	private func buildOriginalBuffers() {
		popBuffer = makeToneBuffer(duration: 0.08, attack: 0.001, release: 0.05) { time in
			let pop = self.sineWave(frequency: 260, time: time) * 0.35
			let click = self.noise(time: time) * 0.08
			return pop + click
		}

		retreatBuffer = makeToneBuffer(duration: 0.18, attack: 0.001, release: 0.16) { time in
			let fall = max(120.0, 320.0 - (time * 900.0))
			return self.sineWave(frequency: fall, time: time) * 0.34
		}

		beatLowBuffer = makeToneBuffer(duration: 0.12, attack: 0.002, release: 0.1) { time in
			self.triangleWave(frequency: 126, time: time) * 0.2
		}

		beatHighBuffer = makeToneBuffer(duration: 0.09, attack: 0.002, release: 0.07) { time in
			self.triangleWave(frequency: 170, time: time) * 0.16
		}

		for lane in 0..<5 {
			let laneFrequency = 660.0 + Double(lane) * 35.0
			hitBuffers[lane] = makeToneBuffer(duration: 0.12, attack: 0.002, release: 0.1) { time in
				let shimmer = self.sineWave(frequency: laneFrequency * 1.5, time: time) * 0.18
				let tone = self.triangleWave(frequency: laneFrequency, time: time) * 0.72
				return tone + shimmer
			}

			missBuffers[lane] = makeToneBuffer(duration: 0.18, attack: 0.002, release: 0.16) { time in
				let downward = max(180.0, 300.0 - (time * 520.0))
				return self.sineWave(frequency: downward, time: time) * 0.55
			}
		}

		startBuffers = [
			makeChordBuffer([261.63, 329.63, 392.0], duration: 0.18),
			makeChordBuffer([261.63, 329.63, 392.0], duration: 0.18),
			makeChordBuffer([392.0, 493.88, 587.33], duration: 0.42)
		].compactMap { $0 }

		everythingBuffers = [
			makeChordBuffer([220.0, 277.18, 329.63], duration: 0.20),
			makeChordBuffer([293.66, 369.99, 440.0], duration: 0.22),
			makeChordBuffer([392.0, 493.88, 587.33], duration: 0.36)
		].compactMap { $0 }
	}

	private func makeChordBuffer(_ frequencies: [Double], duration: TimeInterval) -> AVAudioPCMBuffer? {
		makeToneBuffer(duration: duration, attack: 0.003, release: duration * 0.82) { time in
			frequencies.reduce(0.0) { partial, frequency in
				partial + (self.triangleWave(frequency: frequency, time: time) * 0.18)
			}
		}
	}

	private func makeToneBuffer(
		duration: TimeInterval,
		attack: TimeInterval,
		release: TimeInterval,
		sample: (Double) -> Double
	) -> AVAudioPCMBuffer? {
		let frameCount = max(1, AVAudioFrameCount(duration * sampleRate))
		guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
			  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
			  let samples = buffer.floatChannelData?[0]
		else {
			return nil
		}

		buffer.frameLength = frameCount

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

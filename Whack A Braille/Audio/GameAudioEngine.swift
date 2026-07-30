import AVFoundation
import UIKit

enum GameAudioMode: String, CaseIterable, Identifiable {
	case original
	case silly
	case goofy
	case retro

	var id: String { rawValue }

	var label: String {
		switch self {
		case .original:
			return "Original"
		case .silly:
			return "Silly"
		case .goofy:
			return "Goofy"
		case .retro:
			return "Retro"
		}
	}
}

final class GameAudioEngine {

	static let shared = GameAudioEngine()

	private enum PreparedSoundID: Hashable {
		case pop
		case hit
		case alternateHit
		case miss
		case retreat
		case sillyHit
		case fiftyPoint
		case goofyHit(Int)
		case goofyMiss
		case goofyRetreat
		case retroHit(Int)
		case retroMiss
		case retroRetreat
		case beat(Int)
	}

	private let session = AVAudioSession.sharedInstance()
	private let lanePanMap: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
	private let sampleRate = 44_100.0
	private let maxPreparedPlayersPerSound = 4
	private let maxLowLatencyPlayersPerSound = 4

	private var timerMusicEnabled = true
	private var gameAudioMode: GameAudioMode = .original
	private let lowLatencyEngine = AVAudioEngine()
	private let lowLatencyMixer = AVAudioMixerNode()
	private var activePlayers: [AVAudioPlayer] = []
	private var preparedPlayers: [PreparedSoundID: [AVAudioPlayer]] = [:]
	private var lowLatencyBuffers: [PreparedSoundID: AVAudioPCMBuffer] = [:]
	private var lowLatencyPlayers: [PreparedSoundID: [AVAudioPlayerNode]] = [:]
	private var hasConfiguredLowLatencyEngine = false
	private var hasStartedGameplayPrewarm = false
	private var hasFinishedGameplayPrewarm = false
	private var pendingGameplayPrewarmHandlers: [() -> Void] = []
	private var hasStartedExtendedPrewarm = false
	private var sessionObservers: [NSObjectProtocol] = []
	private var roundBeatWorkItem: DispatchWorkItem?
	private var roundBeatProgressProvider: (() -> Double)?
	private var beatStepIndex = 0
	private var beatRepeatCount = 0
	private var beatRootMidi = 48

	private lazy var popSoundData: Data? = makePopSoundData()
	private lazy var hitSoundData: Data? = makeHitSoundData()
	private lazy var alternateHitSoundData: Data? = makeAlternateHitSoundData()
	private lazy var missSoundData: Data? = makeMissSoundData()
	private lazy var retreatSoundData: Data? = makeRetreatSoundData()
	private lazy var sillyHitSoundData: Data? = loadAudioResourceData(name: "ChanceyBonk_6", fileExtension: "m4a")
	private lazy var fiftyPointSoundData: Data? = loadAudioResourceData(name: "50pts_2", fileExtension: "m4a")
	private lazy var goofyHitSoundData: [Data] = [1, 2, 3].compactMap { makeGoofyHitSoundData(seed: $0) }
	private lazy var goofyMissSoundData: Data? = makeGoofyMissSoundData()
	private lazy var goofyRetreatSoundData: Data? = makeGoofyRetreatSoundData()
	private lazy var retroMissSoundData: Data? = makeRetroMissSoundData()
	private lazy var retroRetreatSoundData: Data? = makeRetroRetreatSoundData()
	private lazy var openingCueData: Data? = makeStartFlourishData()
	private lazy var everythingCueData: Data? = makeEverythingStingerData()
	private lazy var endCueData: Data? = makeEndCueData()
	private lazy var trainingOpeningCueData: [Data] = [1, 2, 3].compactMap { makeTrainingOpeningCueData(seed: $0) }
	private lazy var trainingEndCueData: [Data] = [1, 2, 3].compactMap { makeTrainingEndCueData(seed: $0) }
	private lazy var tier1PrizeFanfareData: [Data] = [1, 2, 3].compactMap { makeTier1PrizeFanfareData(seed: $0) }
	private lazy var tier2PrizeFanfareData: [Data] = [1, 2, 3].compactMap { makeTier2PrizeFanfareData(seed: $0) }
	private lazy var tier3PrizeFanfareData: [Data] = [1, 2, 3].compactMap { makeTier3PrizeFanfareData(seed: $0) }
	private lazy var tier4PrizeFanfareData: [Data] = [1, 2, 3].compactMap { makeTier4PrizeFanfareData(seed: $0) }
	private lazy var tier5PrizeFanfareData: [Data] = [1, 2, 3].compactMap { makeTier5PrizeFanfareData(seed: $0) }
	private lazy var tier6PrizeFanfareData: [Data] = [1, 2, 3].compactMap { makeTier6PrizeFanfareData(seed: $0) }
	private lazy var beatPulseDataByMidi: [Int: Data] = {
		Dictionary(uniqueKeysWithValues: (48...84).compactMap { midi in
			makeBeatPulseData(frequency: midiFrequency(midi)).map { (midi, $0) }
		})
	}()
	private lazy var retroHitSoundDataByRoot: [Int: Data] = {
		Dictionary(uniqueKeysWithValues: (48...84).compactMap { root in
			makeRetroHitSoundData(root: root).map { (root, $0) }
		})
	}()

	private init() {
		observeAudioSession()
	}

	deinit {
		for observer in sessionObservers {
			NotificationCenter.default.removeObserver(observer)
		}
	}

	func prewarm(completion: (() -> Void)? = nil) {
		configureAudioSession()

		if hasFinishedGameplayPrewarm {
			completion?()
			return
		}

		if let completion {
			pendingGameplayPrewarmHandlers.append(completion)
		}

		guard !hasStartedGameplayPrewarm else { return }
		hasStartedGameplayPrewarm = true

		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			guard let self else { return }
			_ = self.popSoundData
			_ = self.hitSoundData
			_ = self.alternateHitSoundData
			_ = self.missSoundData
			_ = self.retreatSoundData
			_ = self.sillyHitSoundData
			_ = self.fiftyPointSoundData
			_ = self.goofyHitSoundData
			_ = self.goofyMissSoundData
			_ = self.goofyRetreatSoundData
			_ = self.retroMissSoundData
			_ = self.retroRetreatSoundData
			_ = self.openingCueData
			_ = self.everythingCueData
			_ = self.endCueData
			_ = self.trainingOpeningCueData
			_ = self.trainingEndCueData
			_ = self.beatPulseDataByMidi
			_ = self.retroHitSoundDataByRoot

			DispatchQueue.main.async {
				self.prewarmPreparedPlayerPools()
				self.hasFinishedGameplayPrewarm = true
				let handlers = self.pendingGameplayPrewarmHandlers
				self.pendingGameplayPrewarmHandlers.removeAll()
				for handler in handlers {
					handler()
				}
				self.prewarmExtendedAudioIfNeeded()
			}
		}
	}

	var isReadyForGameplay: Bool {
		hasFinishedGameplayPrewarm
	}

	func configure(timerMusicEnabled: Bool, gameAudioMode: GameAudioMode = .original) {
		self.timerMusicEnabled = timerMusicEnabled
		self.gameAudioMode = gameAudioMode
		configureAudioSession()
	}

	func prewarmForHomeScreen() {
		prewarm()
	}

	func playOpeningCue(playEverythingIntro: Bool) {
		playGeneratedSound(playEverythingIntro ? everythingCueData : openingCueData, volume: 1.0, pan: 0)
	}

	func playEndCue() {
		playGeneratedSound(endCueData, volume: 1.0, pan: 0)
	}

	func playTrainingOpeningCue() {
		playGeneratedSound(trainingOpeningCueData.randomElement(), volume: 0.98, pan: 0)
	}

	func playTrainingEndCue() {
		playGeneratedSound(trainingEndCueData.randomElement(), volume: 1.0, pan: 0)
	}

	func playPrizeFanfare(for tier: PrizeTier) {
		let variants: [Data]
		let volume: Float

		switch tier {
		case .tier1:
			variants = tier1PrizeFanfareData
			volume = 0.98
		case .tier2:
			variants = tier2PrizeFanfareData
			volume = 1.02
		case .tier3:
			variants = tier3PrizeFanfareData
			volume = 1.05
		case .tier4:
			variants = tier4PrizeFanfareData
			volume = 1.05
		case .tier5:
			variants = tier5PrizeFanfareData
			volume = 1.12
		case .tier6:
			variants = tier6PrizeFanfareData
			volume = 1.16
		}

		playGeneratedSound(variants.randomElement(), volume: volume, pan: 0)
	}

	func startRoundAudio(progressProvider: @escaping () -> Double, timerMusicEnabled: Bool) {
		self.timerMusicEnabled = timerMusicEnabled
		stopRoundBeat()

		guard timerMusicEnabled else { return }

		roundBeatProgressProvider = progressProvider
		startRoundBeat()
	}

	func stopRound() {
		stopRoundBeat()
		stopAllPlayers()
	}

	func playHit(scoreBeforeHit: Int, lane: Int) {
		playHit(scoreBeforeHit: scoreBeforeHit, pan: pan(for: lane))
	}

	func playHit(scoreBeforeHit: Int, pan: Float) {
		let pan = min(max(pan, -1), 1)

		switch gameAudioMode {
		case .original:
			let useAlternateHit = (max(0, scoreBeforeHit) / 10).isMultiple(of: 2)
			let soundData = useAlternateHit ? alternateHitSoundData : hitSoundData
			playPreparedSound(useAlternateHit ? .alternateHit : .hit, data: soundData, volume: 1.34, pan: pan)
		case .silly:
			let rate = Float.random(in: 0.9...1.12)
			playPreparedSound(.sillyHit, data: sillyHitSoundData, volume: 0.62, pan: pan, rate: rate)
			playFiftyPointCueIfNeeded(scoreBeforeHit: scoreBeforeHit)
		case .goofy:
			let rate = Float.random(in: 0.94...1.06)
			let index = goofyHitSoundData.indices.randomElement()
			let soundData = index.map { goofyHitSoundData[$0] }
			playPreparedSound(.goofyHit(index ?? 0), data: soundData, volume: 1.0, pan: pan, rate: rate)
		case .retro:
			let root = currentTimerRootMidi()
			playPreparedSound(.retroHit(root), data: retroHitSoundData(for: root), volume: 0.72, pan: pan)
		}
	}

	func playMiss(lane: Int) {
		playMiss(pan: pan(for: lane))
	}

	func playMiss(pan: Float) {
		let pan = min(max(pan, -1), 1)

		switch gameAudioMode {
		case .original, .silly:
			playPreparedSound(.miss, data: missSoundData, volume: 0.72, pan: pan)
		case .goofy:
			playPreparedSound(.goofyMiss, data: goofyMissSoundData, volume: 0.74, pan: pan)
		case .retro:
			playPreparedSound(.retroMiss, data: retroMissSoundData, volume: 0.5, pan: pan)
		}
	}

	func playMolePop(lane: Int) {
		playMolePop(pan: pan(for: lane))
	}

	func playMolePop(pan: Float) {
		playPreparedSound(.pop, data: popSoundData, volume: 0.45, pan: min(max(pan, -1), 1))
	}

	func playRetreat(lane: Int) {
		playRetreat(pan: pan(for: lane))
	}

	func playRetreat(pan: Float) {
		let pan = min(max(pan, -1), 1)

		switch gameAudioMode {
		case .original, .silly:
			playPreparedSound(.retreat, data: retreatSoundData, volume: 1.0, pan: pan)
		case .goofy:
			playPreparedSound(.goofyRetreat, data: goofyRetreatSoundData, volume: 0.48, pan: pan)
		case .retro:
			playPreparedSound(.retroRetreat, data: retroRetreatSoundData, volume: 0.24, pan: pan)
		}
	}

	private func pan(for lane: Int) -> Float {
		guard lanePanMap.indices.contains(lane) else { return 0 }
		return lanePanMap[lane]
	}

	private func currentTimerRootMidi() -> Int {
		max(48, beatRootMidi)
	}

	private func configureAudioSession() {
		do {
			try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
			try session.setActive(true, options: [])
		} catch {
			// Keep gameplay running even if audio session activation fails.
		}
	}

	private func prewarmPreparedPlayerPools() {
		configureLowLatencyEngineIfNeeded()
		prewarmPreparedSound(.pop, data: popSoundData, count: 5)
		prewarmPreparedSound(.hit, data: hitSoundData)
		prewarmPreparedSound(.alternateHit, data: alternateHitSoundData)
		prewarmPreparedSound(.miss, data: missSoundData)
		prewarmPreparedSound(.retreat, data: retreatSoundData)
		prewarmPreparedSound(.sillyHit, data: sillyHitSoundData)
		prewarmPreparedSound(.fiftyPoint, data: fiftyPointSoundData)
		for (index, data) in goofyHitSoundData.enumerated() {
			prewarmPreparedSound(.goofyHit(index), data: data)
		}
		prewarmPreparedSound(.goofyMiss, data: goofyMissSoundData)
		prewarmPreparedSound(.goofyRetreat, data: goofyRetreatSoundData)
		prewarmPreparedSound(.retroMiss, data: retroMissSoundData)
		prewarmPreparedSound(.retroRetreat, data: retroRetreatSoundData)
		for (midi, data) in beatPulseDataByMidi {
			prewarmPreparedSound(.beat(midi), data: data, count: 2)
		}
		for (root, data) in retroHitSoundDataByRoot {
			prewarmPreparedSound(.retroHit(root), data: data)
		}
		startLowLatencyEngine()
	}

	private func prewarmPreparedSound(_ id: PreparedSoundID, data: Data?, count: Int = 2) {
		guard let data, data.count > 44 else { return }
		prewarmLowLatencySound(id, data: data, count: count)

		let players = (0..<count).compactMap { _ -> AVAudioPlayer? in
			do {
				let player = try AVAudioPlayer(data: data)
				guard player.duration > 0 else { return nil }
				player.enableRate = true
				player.prepareToPlay()
				return player
			} catch {
				return nil
			}
		}

		guard !players.isEmpty else { return }
		preparedPlayers[id] = players
	}

	private func playPreparedSound(_ id: PreparedSoundID, data: Data?, volume: Float, pan: Float, rate: Float = 1.0) {
		guard let data, data.count > 44 else { return }

		if rate == 1.0, playLowLatencySound(id, volume: volume, pan: pan) {
			return
		}

		if let player = availablePreparedPlayer(for: id, data: data) {
			player.stop()
			player.currentTime = 0
			player.volume = volume
			player.pan = pan
			player.enableRate = true
			player.rate = rate
			player.play()
			return
		}

		playGeneratedSound(data, volume: volume, pan: pan, rate: rate)
	}

	private func availablePreparedPlayer(for id: PreparedSoundID, data: Data) -> AVAudioPlayer? {
		if let existing = preparedPlayers[id]?.first(where: { !$0.isPlaying }) {
			return existing
		}

		let currentCount = preparedPlayers[id]?.count ?? 0
		guard currentCount < maxPreparedPlayersPerSound else { return nil }

		do {
			let player = try AVAudioPlayer(data: data)
			guard player.duration > 0 else { return nil }
			player.enableRate = true
			player.prepareToPlay()
			preparedPlayers[id, default: []].append(player)
			return player
		} catch {
			return nil
		}
	}

	private func configureLowLatencyEngineIfNeeded() {
		guard !hasConfiguredLowLatencyEngine else { return }
		hasConfiguredLowLatencyEngine = true

		lowLatencyEngine.attach(lowLatencyMixer)
		lowLatencyEngine.connect(lowLatencyMixer, to: lowLatencyEngine.mainMixerNode, format: nil)
		lowLatencyEngine.prepare()
	}

	private func startLowLatencyEngine() {
		configureLowLatencyEngineIfNeeded()
		guard !lowLatencyEngine.isRunning else { return }

		do {
			try lowLatencyEngine.start()
		} catch {
			// Fall back to prepared AVAudioPlayer playback if the engine cannot start.
		}
	}

	private func restartLowLatencyEngine() {
		configureLowLatencyEngineIfNeeded()
		lowLatencyEngine.stop()
		lowLatencyEngine.prepare()
		startLowLatencyEngine()
	}

	private func rebuildLowLatencyEngine() {
		lowLatencyEngine.stop()
		lowLatencyEngine.reset()
		for players in lowLatencyPlayers.values {
			for player in players {
				player.stop()
				lowLatencyEngine.detach(player)
			}
		}
		lowLatencyPlayers.removeAll()

		let preparedCounts = preparedPlayers.mapValues { min(max($0.count, 1), maxLowLatencyPlayersPerSound) }
		for (id, buffer) in lowLatencyBuffers {
			let count = preparedCounts[id] ?? 2
			prewarmLowLatencyBuffer(id, buffer: buffer, count: count)
		}

		startLowLatencyEngine()
	}

	private func prewarmLowLatencySound(_ id: PreparedSoundID, data: Data, count: Int) {
		configureLowLatencyEngineIfNeeded()

		if lowLatencyBuffers[id] == nil, let buffer = pcmBuffer(fromWaveData: data) {
			lowLatencyBuffers[id] = buffer
		}

		guard let buffer = lowLatencyBuffers[id] else { return }
		let currentCount = lowLatencyPlayers[id]?.count ?? 0
		let targetCount = min(max(count, currentCount), maxLowLatencyPlayersPerSound)
		guard currentCount < targetCount else { return }

		let players = (currentCount..<targetCount).map { _ in
			let player = AVAudioPlayerNode()
			lowLatencyEngine.attach(player)
			lowLatencyEngine.connect(player, to: lowLatencyMixer, format: buffer.format)
			return player
		}

		lowLatencyPlayers[id, default: []].append(contentsOf: players)
	}

	private func prewarmLowLatencyBuffer(_ id: PreparedSoundID, buffer: AVAudioPCMBuffer, count: Int) {
		configureLowLatencyEngineIfNeeded()

		let targetCount = min(max(count, 1), maxLowLatencyPlayersPerSound)
		let players = (0..<targetCount).map { _ in
			let player = AVAudioPlayerNode()
			lowLatencyEngine.attach(player)
			lowLatencyEngine.connect(player, to: lowLatencyMixer, format: buffer.format)
			return player
		}

		lowLatencyPlayers[id] = players
	}

	private func playLowLatencySound(_ id: PreparedSoundID, volume: Float, pan: Float) -> Bool {
		guard let buffer = lowLatencyBuffers[id], let players = lowLatencyPlayers[id], !players.isEmpty else {
			return false
		}

		startLowLatencyEngine()
		guard lowLatencyEngine.isRunning else { return false }

		let player = players.first(where: { !$0.isPlaying }) ?? players[0]
		player.stop()
		player.volume = volume
		player.pan = pan
		player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
		player.play()
		return true
	}

	private func pcmBuffer(fromWaveData data: Data) -> AVAudioPCMBuffer? {
		guard data.count > 44 else { return nil }
		guard String(data: data[0..<4], encoding: .ascii) == "RIFF" else { return nil }
		guard String(data: data[8..<12], encoding: .ascii) == "WAVE" else { return nil }

		var offset = 12
		var audioFormat: UInt16 = 0
		var channelCount: UInt16 = 0
		var waveSampleRate: UInt32 = 0
		var bitsPerSample: UInt16 = 0
		var pcmStart = 0
		var pcmLength = 0

		while offset + 8 <= data.count {
			let chunkID = String(data: data[offset..<(offset + 4)], encoding: .ascii)
			let chunkSize = Int(readUInt32LittleEndian(in: data, at: offset + 4))
			let chunkStart = offset + 8
			let chunkEnd = chunkStart + chunkSize
			guard chunkEnd <= data.count else { return nil }

			if chunkID == "fmt " {
				guard chunkSize >= 16 else { return nil }
				audioFormat = readUInt16LittleEndian(in: data, at: chunkStart)
				channelCount = readUInt16LittleEndian(in: data, at: chunkStart + 2)
				waveSampleRate = readUInt32LittleEndian(in: data, at: chunkStart + 4)
				bitsPerSample = readUInt16LittleEndian(in: data, at: chunkStart + 14)
			} else if chunkID == "data" {
				pcmStart = chunkStart
				pcmLength = chunkSize
			}

			offset = chunkEnd + (chunkSize % 2)
		}

		guard audioFormat == 1, bitsPerSample == 16, channelCount > 0, waveSampleRate > 0, pcmLength > 0 else {
			return nil
		}

		let channels = Int(channelCount)
		let bytesPerFrame = channels * MemoryLayout<Int16>.size
		let frameCount = pcmLength / bytesPerFrame
		guard frameCount > 0 else { return nil }
		guard let format = AVAudioFormat(
			commonFormat: .pcmFormatFloat32,
			sampleRate: Double(waveSampleRate),
			channels: AVAudioChannelCount(channelCount),
			interleaved: false
		) else {
			return nil
		}
		guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
			return nil
		}

		buffer.frameLength = AVAudioFrameCount(frameCount)
		guard let floatChannelData = buffer.floatChannelData else { return nil }

		data.withUnsafeBytes { rawBuffer in
			guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }

			for frame in 0..<frameCount {
				for channel in 0..<channels {
					let sampleOffset = pcmStart + (frame * bytesPerFrame) + (channel * MemoryLayout<Int16>.size)
					let low = UInt16(baseAddress[sampleOffset])
					let high = UInt16(baseAddress[sampleOffset + 1]) << 8
					let sample = Int16(bitPattern: low | high)
					floatChannelData[channel][frame] = Float(sample) / Float(Int16.max)
				}
			}
		}

		return buffer
	}

	private func readUInt16LittleEndian(in data: Data, at offset: Int) -> UInt16 {
		guard offset + 1 < data.count else { return 0 }
		return data.withUnsafeBytes { rawBuffer in
			guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
			return UInt16(baseAddress[offset]) | (UInt16(baseAddress[offset + 1]) << 8)
		}
	}

	private func readUInt32LittleEndian(in data: Data, at offset: Int) -> UInt32 {
		guard offset + 3 < data.count else { return 0 }
		return data.withUnsafeBytes { rawBuffer in
			guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
			return UInt32(baseAddress[offset])
				| (UInt32(baseAddress[offset + 1]) << 8)
				| (UInt32(baseAddress[offset + 2]) << 16)
				| (UInt32(baseAddress[offset + 3]) << 24)
		}
	}

	private func observeAudioSession() {
		let center = NotificationCenter.default

		sessionObservers.append(
			center.addObserver(
				forName: AVAudioSession.routeChangeNotification,
				object: session,
				queue: .main
			) { [weak self] _ in
				self?.configureAudioSession()
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
					self?.configureAudioSession()
					self?.restartLowLatencyEngine()
				}
			}
		)

		sessionObservers.append(
			center.addObserver(
				forName: UIApplication.didBecomeActiveNotification,
				object: nil,
				queue: .main
			) { [weak self] _ in
				self?.configureAudioSession()
			}
		)

		sessionObservers.append(
			center.addObserver(
				forName: UIApplication.willEnterForegroundNotification,
				object: nil,
				queue: .main
			) { [weak self] _ in
				self?.configureAudioSession()
			}
		)

		sessionObservers.append(
			center.addObserver(
				forName: AVAudioSession.mediaServicesWereResetNotification,
				object: session,
				queue: .main
			) { [weak self] _ in
				self?.configureAudioSession()
				self?.rebuildLowLatencyEngine()
			}
		)
	}

	private func playGeneratedSound(_ data: Data?, volume: Float, pan: Float, rate: Float = 1.0) {
		guard let data, data.count > 44 else { return }

		do {
			let player = try AVAudioPlayer(data: data)
			guard player.duration > 0 else { return }
			player.volume = volume
			player.pan = pan
			player.enableRate = true
			player.rate = rate
			player.prepareToPlay()
			activePlayers.append(player)
			player.play()
			purgeFinishedPlayers()
		} catch {
			// Keep gameplay running even if a generated sound cannot be played.
		}
	}

	private func playFiftyPointCueIfNeeded(scoreBeforeHit: Int) {
		guard scoreBeforeHit < 50, scoreBeforeHit + 10 >= 50 else { return }

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
			guard let self else { return }
			self.playPreparedSound(.fiftyPoint, data: self.fiftyPointSoundData, volume: 0.75, pan: 0)
		}
	}

	private func loadAudioResourceData(name: String, fileExtension: String) -> Data? {
		guard
			let url = Bundle.main.url(forResource: name, withExtension: fileExtension)
				?? Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Audio")
		else {
			return nil
		}

		return try? Data(contentsOf: url)
	}

	private func prewarmExtendedAudioIfNeeded() {
		guard !hasStartedExtendedPrewarm else { return }
		hasStartedExtendedPrewarm = true

		DispatchQueue.global(qos: .utility).async { [weak self] in
			guard let self else { return }
			_ = self.tier1PrizeFanfareData
			_ = self.tier2PrizeFanfareData
			_ = self.tier3PrizeFanfareData
			_ = self.tier4PrizeFanfareData
			_ = self.tier5PrizeFanfareData
			_ = self.tier6PrizeFanfareData
		}
	}

	private func startRoundBeat() {
		beatStepIndex = 0
		beatRepeatCount = 0
		beatRootMidi = 48
		scheduleNextBeat()
	}

	private func stopRoundBeat() {
		roundBeatWorkItem?.cancel()
		roundBeatWorkItem = nil
		roundBeatProgressProvider = nil
		beatStepIndex = 0
		beatRepeatCount = 0
		beatRootMidi = 48
	}

	private func scheduleNextBeat() {
		guard timerMusicEnabled, let progressProvider = roundBeatProgressProvider else { return }

		let progress = max(0.0, min(1.0, progressProvider()))
		playBeatPulse(progress: progress)

		let minIntervalMs = 220.0
		let maxIntervalMs = 720.0
		let intervalMs = maxIntervalMs - ((maxIntervalMs - minIntervalMs) * progress)

		var workItem: DispatchWorkItem?
		workItem = DispatchWorkItem { [weak self] in
			guard let self, let workItem else { return }
			guard !workItem.isCancelled else { return }
			self.scheduleNextBeat()
		}

		roundBeatWorkItem = workItem
		if let workItem {
			DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(intervalMs.rounded())), execute: workItem)
		}
	}

	private func playBeatPulse(progress: Double) {
		let pattern = [0, 4, 7, 2]
		let step = pattern[beatStepIndex % pattern.count]
		let targetMidi = min(max(beatRootMidi + step, 48), 84)
		let volume = Float(0.25 + (progress * 0.2))

		playPreparedSound(.beat(targetMidi), data: beatPulseData(for: targetMidi), volume: volume, pan: 0)

		beatStepIndex += 1

		if beatStepIndex % pattern.count == 0 {
			beatRepeatCount += 1

			if beatRepeatCount >= 2 {
				beatRepeatCount = 0
				beatRootMidi += 1
			}
		}
	}

	private func purgeFinishedPlayers() {
		activePlayers.removeAll { !$0.isPlaying }
	}

	private func stopAllPlayers() {
		for player in activePlayers {
			player.stop()
		}
		activePlayers.removeAll()

		for players in preparedPlayers.values {
			for player in players {
				player.stop()
				player.currentTime = 0
			}
		}

		for players in lowLatencyPlayers.values {
			for player in players {
				player.stop()
			}
		}
	}

	private func beatPulseData(for midi: Int) -> Data? {
		beatPulseDataByMidi[midi] ?? makeBeatPulseData(frequency: midiFrequency(midi))
	}

	private func retroHitSoundData(for root: Int) -> Data? {
		retroHitSoundDataByRoot[root] ?? makeRetroHitSoundData(root: root)
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

			let knock = envelope(time, attack: 0.004, release: 0.06, peak: 0.58) *
				sine(lerpExp(start: 920, end: 320, progress: min(time / 0.05, 1)), time)

			let springStart = 0.04
			let spring = springTone(
				time: max(0, time - springStart),
				base: 195,
				duration: 0.85,
				peakGain: 0.4
			)

			return clampSample((sub + subHarm + body + noise + knock + spring) * 0.56)
		}
	}

	private func makeAlternateHitSoundData() -> Data? {
		makeWaveFile(duration: 0.82) { time in
			let sub = envelope(time, attack: 0.012, release: 0.13, peak: 1.05) *
				sine(lerpExp(start: 82, end: 50, progress: min(time / 0.08, 1)), time)

			let body = envelope(time, attack: 0.016, release: 0.18, peak: 0.78) *
				triangle(lerpExp(start: 170, end: 108, progress: min(time / 0.12, 1)), time)

			let click = envelope(time, attack: 0.003, release: 0.05, peak: 0.52) *
				triangle(lerpExp(start: 980, end: 360, progress: min(time / 0.05, 1)), time)

			let snapNoise = envelope(time, attack: 0.006, release: 0.07, peak: 0.19) *
				filteredNoise(seed: 45_901, time: time, carrier: 660)

			let ring = springTone(
				time: max(0, time - 0.03),
				base: 210,
				duration: 0.72,
				peakGain: 0.32
			)

			return clampSample((sub + body + click + snapNoise + ring) * 0.58)
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

	private func makeGoofyHitSoundData(seed: Int) -> Data? {
		let duration = 0.56
		let base = [118.0, 132.0, 146.0][(seed - 1) % 3]

		return makeWaveFile(duration: duration) { time in
			let impactProgress = min(time / 0.14, 1)
			let heavyBonk = envelope(time, attack: 0.006, release: 0.18, peak: 1.18) *
				sine(lerpExp(start: base * 2.15, end: base * 0.72, progress: impactProgress), time)
			let bellyThump = envelope(time, attack: 0.012, release: 0.2, peak: 0.86) *
				sine(lerpExp(start: base * 0.86, end: base * 0.48, progress: min(time / 0.18, 1)), time)
			let hollowBody = envelope(time, attack: 0.012, release: 0.24, peak: 0.72) *
				triangle(lerpExp(start: base * 1.45, end: base * 0.92, progress: min(time / 0.2, 1)), time)
			let rubberTap = envelope(time, attack: 0.002, release: 0.045, peak: 0.38) *
				triangle(lerpExp(start: 620, end: 250, progress: min(time / 0.04, 1)), time)
			let recoilTime = max(0, time - 0.14)
			let recoilProgress = min(recoilTime / 0.27, 1)
			let recoilPitch = lerpExp(start: 540 + Double(seed * 22), end: 230, progress: recoilProgress)
			let recoilWobble = sin(2 * .pi * 18 * recoilTime) * lerp(start: 120, end: 14, progress: recoilProgress)
			let recoil = envelope(recoilTime, attack: 0.008, release: 0.31, peak: 0.38) *
				triangle(recoilPitch + recoilWobble, recoilTime)
			let squeak = envelope(recoilTime, attack: 0.006, release: 0.18, peak: 0.14) *
				sine(lerpExp(start: 1_120, end: 610, progress: min(recoilTime / 0.16, 1)), recoilTime)

			return clampSample((heavyBonk + bellyThump + hollowBody + rubberTap + recoil + squeak) * 0.62)
		}
	}

	private func makeGoofyMissSoundData() -> Data? {
		let duration = 0.32

		return makeWaveFile(duration: duration) { time in
			let progress = min(max(time / duration, 0), 1)
			let wobble = sin(2 * .pi * 7.4 * time) * lerp(start: 50, end: 8, progress: progress)
			let rubberSlide = sine(lerpExp(start: 580 + wobble, end: 210, progress: progress), time)
			let nasalWah = sine(lerpExp(start: 840, end: 310, progress: progress), time) * 0.24
			let env = linearEnvelope(time, attack: 0.03, release: duration, peak: 0.58)

			return clampSample((rubberSlide + nasalWah) * env * 0.46)
		}
	}

	private func makeGoofyRetreatSoundData() -> Data? {
		let duration = 0.42

		return makeWaveFile(duration: duration) { time in
			let progress = min(max(time / duration, 0), 1)
			let bend = sin(2 * .pi * 7.0 * time) * 38
			let zip = sine(lerpExp(start: 260, end: 1_180, progress: progress) + bend, time)
			let chirp = triangle(lerpExp(start: 520, end: 1_640, progress: progress), time) * 0.35
			let env = linearEnvelope(time, attack: 0.012, release: duration, peak: 0.56)

			return clampSample((zip + chirp) * env * 0.5)
		}
	}

	private func makeRetroHitSoundData(root: Int) -> Data? {
		let duration = 0.42
		let timerPattern = [0, 4, 7, 2]
		let sparkleNotes = [root, root + timerPattern[1], root + timerPattern[2], root + 12]

		return makeWaveFile(duration: duration) { time in
			let chordEnv = envelope(time, attack: 0.003, release: 0.16, peak: 0.54)
			let chord = [root, root + timerPattern[1], root + timerPattern[2]].reduce(0.0) { partial, note in
				partial + (square(midiFrequency(note), time) * chordEnv / 3.0)
			}
			let impactPitch = lerpExp(start: midiFrequency(root - 12) * 1.8, end: midiFrequency(root - 12), progress: min(time / 0.08, 1))
			let impact = square(impactPitch, time) * envelope(time, attack: 0.002, release: 0.12, peak: 0.42)

			let stepDuration = 0.045
			let sparkleStart = 0.1
			var sparkle = 0.0
			for (index, note) in sparkleNotes.enumerated() {
				let local = time - sparkleStart - (Double(index) * stepDuration)
				guard local >= 0, local <= stepDuration else { continue }
				let env = linearEnvelope(local, attack: 0.003, release: stepDuration, peak: 0.28)
				sparkle += square(midiFrequency(note), local) * env
			}

			return clampSample((chord * 0.78) + (impact * 0.62) + (sparkle * 0.42))
		}
	}

	private func makeRetroMissSoundData() -> Data? {
		let duration = 0.34
		let notes = [62, 58, 55]

		return makeWaveFile(duration: duration) { time in
			let stepDuration = duration / Double(notes.count)
			let step = min(notes.count - 1, max(0, Int(time / stepDuration)))
			let local = time - (Double(step) * stepDuration)
			let env = linearEnvelope(local, attack: 0.006, release: stepDuration, peak: 0.38)
			let tone = square(midiFrequency(notes[step]), local) * env
			let body = triangle(midiFrequency(notes[step] - 12), local) * env * 0.25

			return clampSample((tone + body) * 0.56)
		}
	}

	private func makeRetroRetreatSoundData() -> Data? {
		let duration = 0.38
		let notes = [79, 76, 72, 67, 64]

		return makeWaveFile(duration: duration) { time in
			let stepDuration = 0.045
			let step = min(notes.count - 1, max(0, Int(time / stepDuration)))
			let local = time - (Double(step) * stepDuration)
			let env = linearEnvelope(local, attack: 0.003, release: stepDuration, peak: 0.42)
			let tone = square(midiFrequency(notes[step]), local) * env
			let echoLocal = time - 0.14 - (Double(step) * stepDuration)
			let echoEnv = linearEnvelope(echoLocal, attack: 0.003, release: stepDuration, peak: 0.16)
			let echo = echoLocal >= 0 ? square(midiFrequency(notes[step] - 12), echoLocal) * echoEnv : 0

			return clampSample((tone * 0.72) + (echo * 0.36))
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
				vibratoRate: 3.1,
				vibratoDepth: 4.0
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

	private func makeTrainingOpeningCueData(seed: Int) -> Data? {
		let beat = 60.0 / 220.0
		let rootChord = [261.63, 329.63, 392.0]
		let resolveChoices: [[Double]] = [
			rootChord.map { $0 * 1.5 },
			[261.63, 392.0, 523.25],
			[246.94, 329.63, 392.0]
		]
		let resolveChord = resolveChoices[(seed - 1) % resolveChoices.count]
		let secondHitStart = beat * (seed == 2 ? 1.25 : 1.4)
		let sustainStart = beat * (seed == 3 ? 2.2 : 2.0)
		let duration = beat * 6.0

		return makeWaveFile(duration: duration) { time in
			var sample = 0.0

			sample += chordBurst(time: time, start: 0, duration: beat, frequencies: rootChord, peak: 0.58)
			sample += chordBurst(time: time, start: secondHitStart, duration: beat, frequencies: rootChord, peak: 0.52)
			sample += sustainedChord(
				time: time,
				start: sustainStart,
				duration: duration - sustainStart,
				frequencies: resolveChord,
				peak: seed == 1 ? 0.66 : 0.62,
				vibratoRate: 4.1,
				vibratoDepth: 2.6
			)

			return clampSample(sample * 0.43)
		}
	}

	private func makeTrainingEndCueData(seed: Int) -> Data? {
		let beat = 60.0 / 180.0
		let progressionChoices: [[([Double], Double, Double)]] = [
			[
				([261.63, 329.63, 392.0], 130.81, beat),
				([261.63, 392.0, 523.25], 130.81, beat),
				([196.0, 246.94, 392.0, 493.88], 98.0, beat * 3.2)
			],
			[
				([261.63, 329.63, 392.0], 130.81, beat),
				([277.18, 329.63, 392.0], 138.59, beat),
				([196.0, 246.94, 392.0, 493.88], 98.0, beat * 3.2)
			],
			[
				([261.63, 329.63, 392.0], 130.81, beat),
				([293.66, 369.99, 440.0], 146.83, beat),
				([196.0, 246.94, 392.0, 493.88], 98.0, beat * 3.2)
			]
		]
		let progression = progressionChoices[(seed - 1) % progressionChoices.count]
		let totalDuration = progression.reduce(0.0) { $0 + $1.2 }

		return makeWaveFile(duration: totalDuration) { time in
			var sample = 0.0
			var cursor = 0.0

			for (index, step) in progression.enumerated() {
				let chord = step.0
				let bass = step.1
				let stepDuration = step.2

				if time >= cursor, time <= cursor + stepDuration {
					let chordSample = chordBurst(
						time: time,
						start: cursor,
						duration: stepDuration,
						frequencies: chord,
						peak: index == progression.count - 1 ? 0.82 : 0.62,
						vibratoRate: index == progression.count - 1 ? 3.8 : nil,
						vibratoDepth: index == progression.count - 1 ? 2.2 : nil
					)
					sample += chordSample

					let local = time - cursor
					let bassEnv = envelope(local, attack: 0.05, release: stepDuration, peak: 0.5)
					sample += sine(bass, local) * bassEnv
				}

				cursor += stepDuration
			}

			return clampSample(sample * 0.44)
		}
	}

	private func makeTier1PrizeFanfareData(seed: Int) -> Data? {
		let baseMidi = 62 + seed
		let melodyChoices: [[Int]] = [
			[0, 4],
			[0, 5],
			[0, 7]
		]
		let melody = melodyChoices[(seed - 1) % melodyChoices.count]
		let noteStarts = [0.0, 0.16]
		let duration = 0.48

		return makeWaveFile(duration: duration) { time in
			var sample = 0.0

			for (index, start) in noteStarts.enumerated() {
				let localTime = time - start
				guard localTime >= 0 else { continue }
				let noteDuration = index == noteStarts.count - 1 ? 0.28 : 0.2
				let freq = 440.0 * pow(2.0, Double(baseMidi + melody[index] - 69) / 12.0)
				let env = linearEnvelope(localTime, attack: 0.008, release: noteDuration, peak: 0.26)
				let horn = triangle(freq, localTime) + (sine(freq * 0.5, localTime) * 0.3)
				sample += horn * env
			}

			return clampSample(sample * 0.66)
		}
	}

	private func makeTier2PrizeFanfareData(seed: Int) -> Data? {
		let baseMidi = 58 + seed
		let melodyChoices: [[Int]] = [
			[0, 4, 7],
			[0, 5, 9],
			[0, 3, 7]
		]
		let melody = melodyChoices[(seed - 1) % melodyChoices.count]
		let noteStarts = [0.0, 0.12, 0.26]
		let duration = 0.7

		return makeWaveFile(duration: duration) { time in
			var sample = 0.0

			for (index, start) in noteStarts.enumerated() {
				let localTime = time - start
				guard localTime >= 0 else { continue }
				let noteDuration = index == noteStarts.count - 1 ? 0.34 : 0.18
				let trumpetFreq = 440.0 * pow(2.0, Double(baseMidi + melody[index] + 12 - 69) / 12.0)
				let tromboneFreq = 440.0 * pow(2.0, Double(baseMidi + melody[index] - 69) / 12.0)
				let env = linearEnvelope(localTime, attack: 0.01, release: noteDuration, peak: 0.2)
				let trumpet = sine(trumpetFreq, localTime) + (triangle(trumpetFreq * 2.0, localTime) * 0.14)
				let trombone = triangle(tromboneFreq, localTime) + (sine(tromboneFreq * 0.5, localTime) * 0.18)
				sample += (trumpet * 0.74 + trombone * 0.62) * env
			}

			let flourish = envelope(time, attack: 0.006, release: 0.1, peak: 0.11) *
				sine(lerpExp(start: 900, end: 520, progress: min(time / 0.1, 1)), time)
			return clampSample((sample + flourish) * 0.7)
		}
	}

	private func makeTier3PrizeFanfareData(seed: Int) -> Data? {
		let baseMidi = 61 + seed
		let melodyChoices: [[Int]] = [
			[0, 4, 7, 11],
			[0, 5, 9, 12],
			[0, 3, 7, 10]
		]
		let melody = melodyChoices[(seed - 1) % melodyChoices.count]
		let noteStarts = [0.0, 0.12, 0.24, 0.36]
		let duration = 0.92

		return makeWaveFile(duration: duration) { time in
			var sample = 0.0

			for (index, start) in noteStarts.enumerated() {
				let localTime = time - start
				guard localTime >= 0 else { continue }
				let noteDuration = index == noteStarts.count - 1 ? 0.46 : 0.2
				let midi = baseMidi + melody[index]
				let freq = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
				let env = linearEnvelope(localTime, attack: 0.01, release: noteDuration, peak: 0.28)
				let body = sine(freq, localTime) + (triangle(freq * 2.0, localTime) * 0.18)
				sample += body * env
			}

			let sparkleOffsets = [0.18, 0.27, 0.34, 0.42]
			for (index, start) in sparkleOffsets.enumerated() {
				let localTime = time - start
				guard localTime >= 0 else { continue }
				let sparkleFreq = 440.0 * pow(2.0, Double(baseMidi + 19 + index + seed - 69) / 12.0)
				let env = linearEnvelope(localTime, attack: 0.008, release: 0.18, peak: 0.08)
				let bell = sine(sparkleFreq, localTime) + (triangle(sparkleFreq * 1.6, localTime) * 0.2)
				sample += bell * env
			}

			return clampSample(sample * 0.72)
		}
	}

	private func makeTier4PrizeFanfareData(seed: Int) -> Data? {
		let baseMidi = 60 + seed
		let chordChoices: [[Int]] = [
			[0, 4, 7, 12],
			[0, 3, 7, 10],
			[0, 5, 9, 12]
		]
		let melodyChoices: [[Int]] = [
			[0, 4, 7, 12],
			[0, 7, 11, 14],
			[0, 5, 9, 12]
		]
		let chord = chordChoices[(seed - 1) % chordChoices.count]
		let melody = melodyChoices[(seed - 1) % melodyChoices.count]
		let noteStarts = [0.0, 0.12, 0.24, 0.37]
		let duration = 0.94

		return makeWaveFile(duration: duration) { time in
			var sample = 0.0
			var finalNoteSample = 0.0

			for (index, start) in noteStarts.enumerated() {
				let localTime = time - start
				guard localTime >= 0 else { continue }

				let noteDuration = index == noteStarts.count - 1 ? 0.62 : 0.22
				let midi = baseMidi + melody[index]
				let baseFreq = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
				let freq: Double
				if index == noteStarts.count - 1 {
					let vibrato = sin(2 * .pi * 4.8 * localTime) * 2.7
					freq = baseFreq + vibrato
				} else {
					freq = baseFreq
				}
				let env = linearEnvelope(localTime, attack: 0.01, release: noteDuration, peak: 0.34)
				let body = sine(freq, localTime)
				let sparkle = triangle(freq * 2.0, localTime) * 0.24
				let noteSample = (body + sparkle) * env
				sample += noteSample

				if index == noteStarts.count - 1 {
					finalNoteSample = noteSample
				}
			}

			for step in chord {
				let localTime = max(0, time - 0.05)
				let freq = 440.0 * pow(2.0, Double(baseMidi + step - 69) / 12.0)
				let env = linearEnvelope(localTime, attack: 0.018, release: 0.48, peak: 0.12)
				let pad = sine(freq, localTime) + (triangle(freq * 0.5, localTime) * 0.2)
				sample += pad * env
			}

			let snap = envelope(time, attack: 0.004, release: 0.045, peak: 0.22) *
				sine(lerpExp(start: 1180, end: 420, progress: min(time / 0.04, 1)), time)
			let shimmerSeed = UInt64(81_000 + (seed * 37))
			let shimmer = envelope(time, attack: 0.01, release: 0.16, peak: 0.12) *
				filteredNoise(seed: shimmerSeed, time: time, carrier: 1_400)
			let glissStart = 0.18
			let glissDuration = 0.4
			let glissSeedOffset = Double(seed) * 0.015
			var chimeGliss = 0.0

			if time >= glissStart, time <= glissStart + glissDuration {
				let localTime = time - glissStart
				let progress = min(max(localTime / glissDuration, 0), 1)
				let startFreq = 440.0 * pow(2.0, Double(baseMidi + 16 - 69) / 12.0)
				let endFreq = 440.0 * pow(2.0, Double(baseMidi + 30 - 69) / 12.0)
				let glissFreq = lerpExp(start: startFreq, end: endFreq, progress: progress)
				let pulse = sin(2 * .pi * (10.5 + glissSeedOffset) * localTime)
				let bellEnv = linearEnvelope(localTime, attack: 0.01, release: glissDuration, peak: 0.1)
				let bellBody = sine(glissFreq, localTime) + (triangle(glissFreq * 1.5, localTime) * 0.22)
				chimeGliss = bellBody * bellEnv * (0.72 + (0.28 * max(0, pulse)))
			}

			let reverbOffsets = [0.065, 0.12, 0.185]
			let reverbGains = [0.12, 0.08, 0.05]
			var reverbTail = 0.0
			let finalStart = noteStarts.last ?? 0.37

			if time >= finalStart {
				for (offset, gain) in zip(reverbOffsets, reverbGains) {
					let reflectedTime = time - offset
					if reflectedTime >= finalStart {
						let reflectionLocal = reflectedTime - finalStart
						let fade = max(0.0, 1.0 - (reflectionLocal / 0.62))
						reverbTail += finalNoteSample * gain * fade
					}
				}
			}

			let endingFade: Double
			if time > 0.62 {
				endingFade = max(0.0, 1.0 - ((time - 0.62) / 0.32))
			} else {
				endingFade = 1.0
			}

			return clampSample((sample + reverbTail + snap + shimmer + chimeGliss) * 0.72 * endingFade)
		}
	}

	private func makeTier5PrizeFanfareData(seed: Int) -> Data? {
		let baseMidi = 64 + seed
		let melodyChoices: [[Int]] = [
			[0, 4, 7, 11, 16, 19],
			[0, 5, 9, 12, 16, 21],
			[0, 7, 11, 14, 19, 23]
		]
		let melody = melodyChoices[(seed - 1) % melodyChoices.count]
		let noteStarts = [0.0, 0.11, 0.23, 0.36, 0.5, 0.68]
		let duration = 1.56

		return makeWaveFile(duration: duration) { time in
			var sample = 0.0
			var finalNoteSample = 0.0

			for (index, start) in noteStarts.enumerated() {
				let localTime = time - start
				guard localTime >= 0 else { continue }
				let noteDuration = index == noteStarts.count - 1 ? 0.72 : 0.22
				let midi = baseMidi + melody[index]
				let baseFreq = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
				let freq: Double
				if index == noteStarts.count - 1 {
					let vibrato = sin(2 * .pi * 4.2 * localTime) * 1.6
					freq = baseFreq + vibrato
				} else {
					freq = baseFreq
				}
				let env = linearEnvelope(localTime, attack: 0.01, release: noteDuration, peak: 0.33)
				let body = sine(freq, localTime) + (triangle(freq * 2.0, localTime) * 0.24)
				let silly = sine(freq * 3.0, localTime) * 0.1
				let noteSample = (body + silly) * env
				sample += noteSample

				if index == noteStarts.count - 1 {
					finalNoteSample = noteSample
				}
			}

			let padChord = [0, 7, 12, 16]
			for step in padChord {
				let localTime = max(0, time - 0.04)
				let freq = 440.0 * pow(2.0, Double(baseMidi + step - 69) / 12.0)
				let env = linearEnvelope(localTime, attack: 0.02, release: 0.72, peak: 0.11)
				let pad = sine(freq, localTime) + (triangle(freq * 0.5, localTime) * 0.14)
				sample += pad * env
			}

			let sparkleStarts = [0.16, 0.28, 0.44, 0.58, 0.82, 0.96]
			for (index, start) in sparkleStarts.enumerated() {
				let localTime = time - start
				guard localTime >= 0 else { continue }
				let progress = Double(index) / Double(max(sparkleStarts.count - 1, 1))
				let freq = lerpExp(start: 900 + Double(seed * 30), end: 1_850 + Double(seed * 40), progress: progress)
				let env = linearEnvelope(localTime, attack: 0.008, release: 0.22, peak: 0.08)
				let bell = sine(freq, localTime) + (triangle(freq * 1.8, localTime) * 0.24)
				sample += bell * env
			}

			let glissStart = 0.52
			let glissDuration = 0.44
			if time >= glissStart, time <= glissStart + glissDuration {
				let localTime = time - glissStart
				let progress = min(max(localTime / glissDuration, 0), 1)
				let startFreq = 440.0 * pow(2.0, Double(baseMidi + 12 - 69) / 12.0)
				let endFreq = 440.0 * pow(2.0, Double(baseMidi + 31 - 69) / 12.0)
				let glissFreq = lerpExp(start: startFreq, end: endFreq, progress: progress)
				let env = linearEnvelope(localTime, attack: 0.01, release: glissDuration, peak: 0.13)
				let gliss = sine(glissFreq, localTime) + (triangle(glissFreq * 1.5, localTime) * 0.22)
				sample += gliss * env
			}

			let reflectionOffsets = [0.08, 0.15, 0.23, 0.31]
			let reflectionGains = [0.12, 0.08, 0.05, 0.03]
			let finalStart = noteStarts.last ?? 0.68
			var tail = 0.0
			if time >= finalStart {
				for (offset, gain) in zip(reflectionOffsets, reflectionGains) {
					let reflectedTime = time - offset
					if reflectedTime >= finalStart {
						let local = reflectedTime - finalStart
						let fade = max(0.0, 1.0 - (local / 0.7))
						tail += finalNoteSample * gain * fade
					}
				}
			}

			let endingFade = time > 1.04 ? max(0.0, 1.0 - ((time - 1.04) / 0.52)) : 1.0
			return clampSample((sample + tail) * 0.76 * endingFade)
		}
	}

	private func makeTier6PrizeFanfareData(seed: Int) -> Data? {
		let baseMidi = 60 + seed
		let melodyChoices: [[Int]] = [
			[0, 7, 12, 16, 19, 24, 28, 31],
			[0, 5, 12, 17, 21, 24, 29, 33],
			[0, 4, 11, 16, 19, 23, 28, 35]
		]
		let melody = melodyChoices[(seed - 1) % melodyChoices.count]
		let noteStarts = [0.0, 0.14, 0.3, 0.48, 0.68, 0.9, 1.15, 1.46]
		let duration = 2.8

		return makeWaveFile(duration: duration) { time in
			var sample = 0.0
			var finalNoteSample = 0.0

			for (index, start) in noteStarts.enumerated() {
				let localTime = time - start
				guard localTime >= 0 else { continue }
				let isFinalNote = index == noteStarts.count - 1
				let noteDuration = isFinalNote ? 1.06 : 0.28
				let midi = baseMidi + melody[index]
				let baseFreq = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
				let vibrato = isFinalNote ? sin(2 * .pi * 4.0 * localTime) * 1.8 : 0
				let env = linearEnvelope(localTime, attack: 0.012, release: noteDuration, peak: isFinalNote ? 0.38 : 0.3)
				let lead = sine(baseFreq + vibrato, localTime)
				let upper = triangle((baseFreq * 2.0) + vibrato, localTime) * 0.2
				let chorusA = sine((baseFreq * 0.995) + vibrato, localTime) * 0.42
				let chorusB = sine((baseFreq * 1.006) + vibrato, localTime) * 0.38
				let shimmer = sine(baseFreq * 3.0, localTime) * 0.08
				let noteSample = (lead + upper + chorusA + chorusB + shimmer) * env
				sample += noteSample

				if isFinalNote {
					finalNoteSample = noteSample
				}
			}

			let choirChord = [0, 7, 12, 16, 19, 24]
			for (index, step) in choirChord.enumerated() {
				let localTime = max(0, time - 0.18 - (Double(index) * 0.018))
				let freq = 440.0 * pow(2.0, Double(baseMidi + step - 69) / 12.0)
				let env = linearEnvelope(localTime, attack: 0.18, release: 2.08, peak: 0.09)
				let voice = sine(freq * 0.997, localTime) + sine(freq * 1.004, localTime) + (triangle(freq * 0.5, localTime) * 0.18)
				sample += voice * env
			}

			let sparkleStarts = [0.24, 0.34, 0.5, 0.62, 0.78, 0.96, 1.14, 1.32, 1.58, 1.82, 2.08]
			for (index, start) in sparkleStarts.enumerated() {
				let localTime = time - start
				guard localTime >= 0 else { continue }
				let progress = Double(index) / Double(max(sparkleStarts.count - 1, 1))
				let freq = lerpExp(start: 1_150 + Double(seed * 45), end: 3_250 + Double(seed * 60), progress: progress)
				let env = linearEnvelope(localTime, attack: 0.006, release: 0.3, peak: 0.082)
				let bell = sine(freq, localTime) + (triangle(freq * 1.7, localTime) * 0.28)
				sample += bell * env
			}

			let glissStart = 1.1
			let glissDuration = 0.72
			if time >= glissStart, time <= glissStart + glissDuration {
				let localTime = time - glissStart
				let progress = min(max(localTime / glissDuration, 0), 1)
				let startFreq = 440.0 * pow(2.0, Double(baseMidi + 12 - 69) / 12.0)
				let endFreq = 440.0 * pow(2.0, Double(baseMidi + 38 - 69) / 12.0)
				let glissFreq = lerpExp(start: startFreq, end: endFreq, progress: progress)
				let pulse = 0.78 + (0.22 * sin(2 * .pi * 9.0 * localTime))
				let env = linearEnvelope(localTime, attack: 0.02, release: glissDuration, peak: 0.16)
				let gliss = sine(glissFreq, localTime) + (triangle(glissFreq * 1.5, localTime) * 0.22)
				sample += gliss * env * pulse
			}

			let finalStart = noteStarts.last ?? 1.46
			let reflectionOffsets = [0.09, 0.17, 0.28, 0.42, 0.58, 0.74]
			let reflectionGains = [0.15, 0.11, 0.08, 0.055, 0.038, 0.026]
			var tail = 0.0
			if time >= finalStart {
				for (offset, gain) in zip(reflectionOffsets, reflectionGains) {
					let reflectedTime = time - offset
					if reflectedTime >= finalStart {
						let local = reflectedTime - finalStart
						let fade = max(0.0, 1.0 - (local / 1.18))
						tail += finalNoteSample * gain * fade
					}
				}
			}

			let cymbalSeed = UInt64(96_000 + (seed * 127))
			let cymbal = envelope(time, attack: 0.012, release: 0.7, peak: 0.075) *
				filteredNoise(seed: cymbalSeed, time: time, carrier: 2_400)
			let endingFade = time > 2.22 ? max(0.0, 1.0 - ((time - 2.22) / 0.58)) : 1.0
			return clampSample((sample + tail + cymbal) * 0.68 * endingFade)
		}
	}

	private func makeBeatPulseData(frequency: Double) -> Data? {
		let duration = 0.28
		return makeWaveFile(duration: duration) { time in
			let noteDuration = 0.26
			let attackTime = 0.04
			let env = envelope(time, attack: attackTime, release: noteDuration, peak: 0.42)
			return clampSample(triangle(frequency, time) * env * 0.75)
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

	private func square(_ frequency: Double, _ time: Double) -> Double {
		guard frequency > 0 else { return 0 }
		return sine(frequency, time) >= 0 ? 1.0 : -1.0
	}

	private func sine(_ frequency: Double, _ time: Double) -> Double {
		sin(2.0 * .pi * frequency * time)
	}

	private func midiFrequency(_ note: Int) -> Double {
		440.0 * pow(2.0, Double(note - 69) / 12.0)
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

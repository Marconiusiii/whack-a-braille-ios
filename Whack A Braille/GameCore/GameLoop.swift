import Foundation

@MainActor
final class GameLoop {

	struct Options {
		let modeId: String
		let durationSeconds: Int
		let inputMode: InputMode
		let difficulty: Difficulty
		let speakBrailleDots: Bool
		let characterEcho: Bool
		let timerMusicEnabled: Bool
		let spatialMoleMappingEnabled: Bool
	}

	var onRoundEnded: ((RoundResult) -> Void)?
	var onScoreUpdated: ((Int, Int) -> Void)?
	var onActiveMoleChanged: ((Int?, BrailleItem?) -> Void)?
	var onInputResetRequested: (() -> Void)?

	private(set) var isRunning: Bool = false
	private(set) var roundEnding: Bool = false
	private(set) var score: Int = 0
	private(set) var hitStreak: Int = 0
	private(set) var currentMoleId: Int = 0

	private let laneCount = 5
	private let maxSameLaneInRow = 2
	private let trainingMoleCap = 15

	private let startIntervalMs = 1_000
	private let endIntervalMs = 360
	private let startUpTimeMs = 760
	private let endUpTimeMs = 340

	private let difficultyMultipliers: [Difficulty: Double] = [
		.beginner: 1.5,
		.normal: 1.0,
		.supreme: 0.5
	]

	private let qwertyLaneMap: [String: Int] = [
		"1": 0, "2": 0,
		"3": 1, "4": 1,
		"5": 2, "6": 2,
		"7": 3, "8": 3,
		"9": 4, "0": 4,
		"q": 0, "a": 0, "z": 0, "w": 0, "s": 0, "x": 0,
		"e": 1, "d": 1, "c": 1, "r": 1, "f": 1, "v": 1,
		"t": 2, "g": 2, "b": 2, "y": 2, "h": 2, "n": 2,
		"u": 3, "j": 3, "m": 3, "i": 3, "k": 3, ",": 3,
		"o": 4, "l": 4, ".": 4, "p": 4, ";": 4, "/": 4, "[": 4, "]": 4, "\\": 4, "'": 4
	]

	private var currentOptions = Options(
		modeId: "grade1LettersNumbers",
		durationSeconds: 30,
		inputMode: .qwerty,
		difficulty: .normal,
		speakBrailleDots: false,
		characterEcho: false,
		timerMusicEnabled: true,
		spatialMoleMappingEnabled: true
	)

	private var availableItems: [BrailleItem] = []
	private var roundItems: [BrailleItem] = []
	private var roundLaneItems: [BrailleItem?] = []

	private var activeLane: Int?
	private var missRegisteredForMole = false
	private var activeMoleShownAtMs = 0
	private var activeMoleUpTimeMs = 0

	private var hitsThisRound = 0
	private var missesThisRound = 0
	private var escapesThisRound = 0
	private var streakBonusCount = 0
	private var speedHitCount = 0
	private var speedBonusTickets = 0
	private var trainingMolesCompleted = 0
	private var lastTrainingMissAtMs = 0

	private var roundDurationMs = 30_000
	private var roundStartTimeMs = 0
	private var lastLaneIndex: Int?
	private var sameLaneRunCount = 0

	private var roundTimer: DispatchSourceTimer?
	private var moleTimer: DispatchSourceTimer?
	private var moleUpTimer: DispatchSourceTimer?

	func startRound(options: Options) {
		guard !isRunning else { return }

		currentOptions = options
		availableItems = BrailleRegistry.getItems(for: options.modeId)
		roundItems = pickRoundItems(
			modeId: options.modeId,
			pool: availableItems,
			useSpatialMapping: options.spatialMoleMappingEnabled
		)
		roundLaneItems = buildRoundLaneItems(
			modeId: options.modeId,
			items: roundItems,
			useSpatialMapping: options.spatialMoleMappingEnabled
		)

		score = 0
		hitStreak = 0
		hitsThisRound = 0
		missesThisRound = 0
		escapesThisRound = 0
		streakBonusCount = 0
		speedHitCount = 0
		speedBonusTickets = 0
		trainingMolesCompleted = 0
		lastTrainingMissAtMs = 0

		roundDurationMs = options.durationSeconds * 1000
		roundStartTimeMs = TimeUtils.nowMs()
		lastLaneIndex = nil
		sameLaneRunCount = 0
		activeLane = nil
		currentMoleId = 0
		missRegisteredForMole = false
		activeMoleShownAtMs = 0
		activeMoleUpTimeMs = 0

		isRunning = true
		roundEnding = false

		cancelTimers()
		onScoreUpdated?(score, hitStreak)
		onActiveMoleChanged?(nil, nil)

		GameAudioEngine.shared.startRoundAudio(
			progressProvider: { [weak self] in
				self?.getProgress() ?? 0
			},
			timerMusicEnabled: options.timerMusicEnabled && options.difficulty != .training
		)

		if options.difficulty == .training {
			scheduleNextTrainingMole(extraDelayMs: 0)
			return
		}

		scheduleRoundEnd()
		scheduleNextMole(extraDelayMs: 0)
	}

	func stopRound() {
		endRoundNow(canceled: true)
	}

	func finishRoundEarly() {
		endRoundNow(canceled: false)
	}

	func repeatCurrentTarget() {
		guard let item = currentItem else { return }
		SpeechEngine.shared.speak(buildAnnounceText(for: item), interrupt: true)
	}

	func handleAttempt(_ attempt: Attempt) {
		guard isRunning, !roundEnding else { return }
		guard let activeLane, let currentItem = laneItem(for: activeLane) else { return }
		guard attempt.moleId == currentMoleId else { return }
		guard attempt.key != "`" else {
			repeatCurrentTarget()
			return
		}

		if currentOptions.inputMode == .perkins && attempt.type == .qwerty {
			return
		}

		let hit: Bool

		switch attempt.type {
		case .perkins:
			hit = attempt.dotMask == currentItem.dotMask
		case .qwerty:
			hit = matchesInput(normalize(attempt.key), item: currentItem)
		case .brailleText:
			hit = matchesInput(normalize(attempt.char), item: currentItem)
		}

		if hit {
			handleHit()
			return
		}

		if currentOptions.difficulty == .training {
			handleTrainingMiss()
			return
		}

		guard !missRegisteredForMole else { return }
		missRegisteredForMole = true
		handleMiss()
	}

	private var currentItem: BrailleItem? {
		guard let activeLane else { return nil }
		return laneItem(for: activeLane)
	}

	private func laneItem(for lane: Int) -> BrailleItem? {
		guard roundLaneItems.indices.contains(lane) else { return nil }
		return roundLaneItems[lane]
	}

	private func scheduleRoundEnd() {
		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(roundDurationMs))
		timer.setEventHandler { [weak self] in
			self?.requestRoundEnd()
		}
		timer.resume()
		roundTimer = timer
	}

	private func requestRoundEnd() {
		guard isRunning else { return }

		roundEnding = true
		moleTimer?.cancel()
		moleTimer = nil

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(computeRoundEndGraceMs()))
		timer.setEventHandler { [weak self] in
			self?.endRoundNow(canceled: false)
		}
		timer.resume()

		roundTimer?.cancel()
		roundTimer = timer
	}

	private func endRoundNow(canceled: Bool) {
		guard isRunning else { return }

		isRunning = false
		roundEnding = false

		cancelTimers()
		clearActiveMole()
		onInputResetRequested?()
		GameAudioEngine.shared.stopRound()

		if canceled {
			SpeechEngine.shared.cancel()
		}

		let isTraining = currentOptions.difficulty == .training
		let baseTickets = isTraining ? 0 : scoreToTickets(score)
		let streakTickets = isTraining ? 0 : streakBonusCount
		let speedTickets = isTraining ? 0 : speedBonusTickets

		onRoundEnded?(
			RoundResult(
				modeId: currentOptions.modeId,
				inputMode: effectiveInputMode,
				durationSeconds: currentOptions.durationSeconds,
				isTraining: isTraining,
				trainingMolesCompleted: trainingMolesCompleted,
				score: score,
				hits: hitsThisRound,
				misses: missesThisRound,
				escapes: escapesThisRound,
				streakBonusCount: streakBonusCount,
				canceled: canceled,
				baseTickets: baseTickets,
				streakBonusTickets: streakTickets,
				speedBonusTickets: speedTickets
			)
		)
	}

	private var effectiveInputMode: InputMode {
		currentOptions.modeId == "everything" ? .perkins : currentOptions.inputMode
	}

	private func scheduleNextMole(extraDelayMs: Int) {
		guard isRunning, !roundEnding else { return }

		let delay = getCurrentInterval() + Int.random(in: 0..<120) + extraDelayMs
		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(delay))
		timer.setEventHandler { [weak self] in
			self?.showRandomMole()
		}
		timer.resume()

		moleTimer?.cancel()
		moleTimer = timer
	}

	private func scheduleNextTrainingMole(extraDelayMs: Int) {
		guard isRunning, !roundEnding else { return }

		if trainingMolesCompleted >= trainingMoleCap {
			endRoundNow(canceled: false)
			return
		}

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(max(0, extraDelayMs)))
		timer.setEventHandler { [weak self] in
			self?.showTrainingMole()
		}
		timer.resume()

		moleTimer?.cancel()
		moleTimer = timer
	}

	private func showTrainingMole() {
		showMole(trainingMode: true)
	}

	private func showRandomMole() {
		showMole(trainingMode: false)
	}

	private func showMole(trainingMode: Bool) {
		guard isRunning, !roundEnding else { return }

		clearActiveMole()
		currentMoleId += 1
		missRegisteredForMole = false

		let lane = pickNextLaneIndex()
		guard let item = laneItem(for: lane) else {
			clearActiveMole()
			scheduleFollowUp(afterTraining: trainingMode)
			return
		}

		let moleId = currentMoleId
		activeLane = lane
		onActiveMoleChanged?(nil, nil)

		let announceText = buildAnnounceText(for: item)
		let speechDurationMs = SpeechEngine.shared.speak(announceText, interrupt: true)
		let baseUpTimeMs = trainingMode ? 0 : getCurrentUpTime()

		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80)) { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding else { return }
			guard self.currentMoleId == moleId, self.activeLane == lane else { return }

			self.activeMoleShownAtMs = TimeUtils.nowMs()
			self.onActiveMoleChanged?(lane, item)
			GameAudioEngine.shared.playMolePop(lane: lane)
		}

		if trainingMode {
			activeMoleUpTimeMs = 0
			return
		}

		activeMoleUpTimeMs = computeMoleWindowMs(
			baseUpTimeMs: baseUpTimeMs,
			speechDurationMs: speechDurationMs
		)

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(activeMoleUpTimeMs))
		timer.setEventHandler { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding else { return }
			guard self.currentMoleId == moleId, self.activeLane == lane else { return }

			self.escapesThisRound += 1
			self.hitStreak = 0
			self.onScoreUpdated?(self.score, self.hitStreak)
			self.onInputResetRequested?()
			GameAudioEngine.shared.playRetreat(lane: lane)

			self.clearActiveMole()
			self.scheduleNextMole(extraDelayMs: 0)
		}
		timer.resume()

		moleUpTimer?.cancel()
		moleUpTimer = timer
	}

	private func handleHit() {
		guard let lane = activeLane else { return }

		if currentOptions.difficulty == .training {
			GameAudioEngine.shared.playHit(scoreBeforeHit: 0, lane: lane)
			hitsThisRound += 1
			trainingMolesCompleted += 1
			onInputResetRequested?()
			missRegisteredForMole = true
			moleUpTimer?.cancel()
			moleUpTimer = nil
			clearActiveMole()
			scheduleNextTrainingMole(extraDelayMs: 180)
			return
		}

		let previousScore = score
		hitsThisRound += 1
		hitStreak += 1
		score += 10

		if hitStreak % 5 == 0 {
			score += 10
			streakBonusCount += 1
		}

		let reactionMs = TimeUtils.nowMs() - activeMoleShownAtMs
		let speedThresholdMs = Int(Double(activeMoleUpTimeMs) * 0.55)

		if reactionMs <= speedThresholdMs {
			speedHitCount += 1
			if speedHitCount % 3 == 0 && speedBonusTickets < 5 {
				speedBonusTickets += 1
			}
		}

		GameAudioEngine.shared.playHit(scoreBeforeHit: previousScore, lane: lane)
		onInputResetRequested?()
		missRegisteredForMole = true
		moleUpTimer?.cancel()
		moleUpTimer = nil
		clearActiveMole()
		onScoreUpdated?(score, hitStreak)
		scheduleNextMole(extraDelayMs: 0)
	}

	private func handleTrainingMiss() {
		let now = TimeUtils.nowMs()
		guard now - lastTrainingMissAtMs >= 200 else { return }
		lastTrainingMissAtMs = now

		if let lane = activeLane {
			GameAudioEngine.shared.playMiss(lane: lane)
		}
	}

	private func handleMiss() {
		guard let lane = activeLane else { return }

		missesThisRound += 1
		hitStreak = 0
		score = max(0, score - 2)

		GameAudioEngine.shared.playMiss(lane: lane)
		onInputResetRequested?()
		onScoreUpdated?(score, hitStreak)
	}

	private func buildAnnounceText(for item: BrailleItem) -> String {
		var text = item.announceText

		if item.modeTags.contains("grade1Letters"), currentOptions.characterEcho, let nato = item.nato {
			text += ", \(nato)"
		}

		if currentOptions.difficulty == .training, currentOptions.speakBrailleDots, !item.dots.isEmpty {
			if item.dots.count == 1 {
				text += ", Dot \(item.dots[0])"
			} else {
				text += ", Dots \(item.dots.map(String.init).joined(separator: " "))"
			}
		}

		return text
	}

	private func scheduleFollowUp(afterTraining trainingMode: Bool) {
		if trainingMode {
			scheduleNextTrainingMole(extraDelayMs: 0)
		} else {
			scheduleNextMole(extraDelayMs: 0)
		}
	}

	private func pickRoundItems(modeId: String, pool: [BrailleItem], useSpatialMapping: Bool) -> [BrailleItem] {
		if !useSpatialMapping || !isSpatialMappingEligibleMode(modeId) {
			return pickFiveItems(from: pool)
		}

		var copy = pool
		copy.shuffle()

		var selected: [BrailleItem] = []
		var occupied = Set<Int>()

		for item in copy {
			guard let lane = laneForItem(item), !occupied.contains(lane) else { continue }
			selected.append(item)
			occupied.insert(lane)
			if selected.count >= laneCount {
				break
			}
		}

		return selected.isEmpty ? pickFiveItems(from: pool) : selected
	}

	private func buildRoundLaneItems(modeId: String, items: [BrailleItem], useSpatialMapping: Bool) -> [BrailleItem?] {
		var lanes = Array<BrailleItem?>(repeating: nil, count: laneCount)

		if !useSpatialMapping || !isSpatialMappingEligibleMode(modeId) {
			for index in 0..<min(laneCount, items.count) {
				lanes[index] = items[index]
			}
			return lanes
		}

		var occupied = Set<Int>()

		for item in items {
			guard let lane = laneForItem(item), !occupied.contains(lane) else { continue }
			lanes[lane] = item
			occupied.insert(lane)
		}

		return lanes
	}

	private func pickFiveItems(from pool: [BrailleItem]) -> [BrailleItem] {
		var copy = pool
		copy.shuffle()
		return Array(copy.prefix(min(laneCount, copy.count)))
	}

	private func isSpatialMappingEligibleMode(_ modeId: String) -> Bool {
		switch modeId {
		case "typingSimpleHomeRow", "typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow",
			"letters-aj", "letters-at", "grade1Letters", "grade1Numbers", "grade1LettersNumbers":
			return true
		default:
			return false
		}
	}

	private func laneForItem(_ item: BrailleItem) -> Int? {
		guard let key = item.standardKey?.lowercased() else { return nil }
		return qwertyLaneMap[key]
	}

	private func pickNextLaneIndex() -> Int {
		let candidates = roundLaneItems.indices.filter { roundLaneItems[$0] != nil }
		guard !candidates.isEmpty else { return 0 }
		guard candidates.count > 1 else { return candidates[0] }

		var filtered = candidates.filter { $0 != activeLane }

		if let lastLaneIndex, sameLaneRunCount >= maxSameLaneInRow {
			let withoutRepeat = filtered.filter { $0 != lastLaneIndex }
			if !withoutRepeat.isEmpty {
				filtered = withoutRepeat
			}
		}

		if filtered.isEmpty {
			filtered = candidates
		}

		let lane = filtered.randomElement() ?? candidates[0]

		if lane == lastLaneIndex {
			sameLaneRunCount += 1
		} else {
			self.lastLaneIndex = lane
			sameLaneRunCount = 1
		}

		return lane
	}

	private func clearActiveMole() {
		activeLane = nil
		activeMoleShownAtMs = 0
		onActiveMoleChanged?(nil, nil)
	}

	private func getProgress() -> Double {
		guard roundDurationMs > 0 else { return 0 }
		let elapsed = TimeUtils.nowMs() - roundStartTimeMs
		var progress = min(Double(elapsed) / Double(roundDurationMs), 1.0)

		if roundDurationMs >= 45_000 {
			if progress > 0.3 && progress < 0.7 {
				progress = 0.3 + (progress - 0.3) * 1.6
			} else if progress >= 0.7 {
				progress = 0.9
			}
		}

		return min(progress, 1.0)
	}

	private func getCurrentInterval() -> Int {
		var interval = TimeUtils.lerp(start: startIntervalMs, end: endIntervalMs, t: getProgress())

		if getProgress() > 0.7 {
			interval = Int(Double(interval) * 0.6)
		}

		let multiplier = difficultyMultipliers[currentOptions.difficulty] ?? 1.0
		return max(Int(Double(interval) * multiplier), 240)
	}

	private func getCurrentUpTime() -> Int {
		let base = TimeUtils.lerp(start: startUpTimeMs, end: endUpTimeMs, t: getProgress())
		let multiplier = difficultyMultipliers[currentOptions.difficulty] ?? 1.0
		return Int(Double(base) * multiplier)
	}

	private func computeMoleWindowMs(baseUpTimeMs: Int, speechDurationMs: Int) -> Int {
		let reactionBufferMs = 380
		let minUpTimeMs = 550
		let maxUpTimeMs = 2_200
		let effectiveSpeechDurationMs = max(300, speechDurationMs)

		return min(
			max(baseUpTimeMs + effectiveSpeechDurationMs + reactionBufferMs, minUpTimeMs),
			maxUpTimeMs
		)
	}

	private func computeRoundEndGraceMs() -> Int {
		min(max(350, 0), 750)
	}

	private func scoreToTickets(_ score: Int) -> Int {
		if score >= 200 { return 20 }
		if score >= 150 { return 15 }
		if score >= 100 { return 10 }
		if score >= 50 { return 5 }
		return 0
	}

	private func cancelTimers() {
		roundTimer?.cancel()
		moleTimer?.cancel()
		moleUpTimer?.cancel()

		roundTimer = nil
		moleTimer = nil
		moleUpTimer = nil
	}

	private func normalize(_ value: String?) -> String {
		String(value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
	}

	private func matchesInput(_ input: String, item: BrailleItem) -> Bool {
		guard !input.isEmpty else { return false }
		return item.acceptedTextInputs.contains(input)
	}
}

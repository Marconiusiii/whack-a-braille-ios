import Foundation

@MainActor
final class GameLoop {

	var onRoundEnded: ((RoundResult) -> Void)?
	var onScoreUpdated: ((Int, Int) -> Void)?
	var onActiveMoleChanged: ((Int?, BrailleItem?) -> Void)?

	private(set) var isRunning: Bool = false
	private(set) var roundEnding: Bool = false

	private(set) var score: Int = 0
	private(set) var hitStreak: Int = 0
	private(set) var hitsThisRound: Int = 0
	private(set) var missesThisRound: Int = 0
	private(set) var escapesThisRound: Int = 0
	private(set) var streakBonusCount: Int = 0
	private(set) var speedHitCount: Int = 0
	private(set) var speedBonusTickets: Int = 0

	var currentMoleId: Int {
		activeMoleId
	}

	private let laneCount = 5
	private let maxSameLaneInRow = 2

	private let startIntervalMs: Int = 900
	private let endIntervalMs: Int = 300
	private let startUpTimeMs: Int = 650
	private let endUpTimeMs: Int = 250

	private let difficultyMultipliers: [Difficulty: Double] = [
		.beginner: 1.5,
		.normal: 1.0,
		.supreme: 0.5
	]

	private var currentModeId: String = ""
	private var currentInputMode: InputMode = .qwerty
	private var currentDurationSeconds: Int = 30
	private var difficultyMultiplier: Double = 1.0

	private var roundItems: [BrailleItem] = []

	private var roundDurationMs: Int = 30_000
	private var roundStartTimeMs: Int = 0

	private var activeMoleIndex: Int?
	private var activeMoleId: Int = 0
	private var missRegisteredForMole: Bool = false
	private var moleBecameActiveMs: Int = 0
	private var activeMoleUpTimeMs: Int = 0

	private var lastLaneIndex: Int?
	private var sameLaneRunCount: Int = 0

	private var roundTimer: DispatchSourceTimer?
	private var moleTimer: DispatchSourceTimer?
	private var moleUpTimer: DispatchSourceTimer?

	func startRound(
		modeId: String,
		durationSeconds: Int,
		inputMode: InputMode,
		difficulty: Difficulty = .normal,
		itemsForMode: [BrailleItem]
	) {
		guard !isRunning else { return }

		currentModeId = modeId
		currentDurationSeconds = durationSeconds
		currentInputMode = modeId == "everything" ? .perkins : inputMode
		difficultyMultiplier = difficultyMultipliers[difficulty] ?? 1.0
		roundDurationMs = durationSeconds * 1000
		roundStartTimeMs = TimeUtils.nowMs()
		roundItems = buildRoundItems(from: itemsForMode)

		score = 0
		hitStreak = 0
		hitsThisRound = 0
		missesThisRound = 0
		escapesThisRound = 0
		streakBonusCount = 0
		speedHitCount = 0
		speedBonusTickets = 0

		activeMoleIndex = nil
		activeMoleId = 0
		missRegisteredForMole = false
		moleBecameActiveMs = 0
		activeMoleUpTimeMs = 0
		lastLaneIndex = nil
		sameLaneRunCount = 0

		isRunning = true
		roundEnding = false

		cancelTimers()
		onScoreUpdated?(score, hitStreak)
		onActiveMoleChanged?(nil, nil)

		GameAudioEngine.shared.startRound(progressProvider: { [weak self] in
			self?.getProgress() ?? 0
		})

		scheduleRoundEnd()
		scheduleNextMole(extraDelayMs: 180)
	}

	func stopRound() {
		endRoundNow(canceled: true)
	}

	func repeatCurrentTarget() {
		guard
			isRunning,
			let activeMoleIndex,
			activeMoleIndex < roundItems.count
		else {
			return
		}

		SpeechEngine.shared.speak(roundItems[activeMoleIndex].announceText)
	}

	func handleAttempt(_ attempt: Attempt) {
		guard isRunning, !roundEnding else { return }
		guard let activeMoleIndex, activeMoleIndex < roundItems.count else { return }
		guard attempt.moleId == activeMoleId else { return }
		guard attempt.key != "`" else {
			repeatCurrentTarget()
			return
		}

		if currentInputMode == .perkins && attempt.type == .qwerty {
			return
		}

		let currentItem = roundItems[activeMoleIndex]
		let isHit: Bool

		switch attempt.type {
		case .perkins:
			if let dotMask = attempt.dotMask {
				isHit = dotMask == currentItem.dotMask
			} else {
				isHit = normalize(attempt.char) == normalize(currentItem.id)
			}
		case .brailleText:
			isHit = normalize(attempt.char) == normalize(currentItem.id)
		case .qwerty:
			isHit = normalize(attempt.key) == normalize(currentItem.standardKey)
		}

		if isHit {
			handleHit()
			return
		}

		guard !missRegisteredForMole else { return }
		missRegisteredForMole = true
		handleMiss()
	}

	private func handleHit() {
		guard let lane = activeMoleIndex else { return }

		let previousScore = score

		hitsThisRound += 1
		hitStreak += 1
		score += 10

		if hitStreak % 5 == 0 {
			score += 10
			streakBonusCount += 1
		}

		let reactionMs = TimeUtils.nowMs() - moleBecameActiveMs
		let speedThresholdMs = Int(Double(activeMoleUpTimeMs) * 0.55)

		if reactionMs > 0, reactionMs <= speedThresholdMs {
			speedHitCount += 1
			if speedHitCount % 3 == 0 && speedBonusTickets < 5 {
				speedBonusTickets += 1
			}
		}

		GameAudioEngine.shared.playHit(scoreBeforeHit: previousScore, lane: lane)

		missRegisteredForMole = true
		moleUpTimer?.cancel()
		moleUpTimer = nil

		clearActiveMole()
		onScoreUpdated?(score, hitStreak)
		scheduleNextMole(extraDelayMs: 0)
	}

	private func handleMiss() {
		guard let lane = activeMoleIndex else { return }

		missesThisRound += 1
		hitStreak = 0
		score = max(0, score - 2)

		GameAudioEngine.shared.playMiss(lane: lane)
		onScoreUpdated?(score, hitStreak)
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
		timer.schedule(deadline: .now() + .milliseconds(computeRoundEndGraceMs(baseGraceMs: 350, maxGraceMs: 750)))
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
		GameAudioEngine.shared.stopRound()
		SpeechEngine.shared.cancel()

		let result = RoundResult(
			modeId: currentModeId,
			inputMode: currentInputMode,
			durationSeconds: currentDurationSeconds,
			score: score,
			hits: hitsThisRound,
			misses: missesThisRound,
			escapes: escapesThisRound,
			streakBonusCount: streakBonusCount,
			canceled: canceled,
			baseTickets: scoreToTickets(score),
			streakBonusTickets: streakBonusCount,
			speedBonusTickets: speedBonusTickets
		)

		onRoundEnded?(result)
	}

	private func computeRoundEndGraceMs(baseGraceMs: Int, maxGraceMs: Int) -> Int {
		min(max(baseGraceMs, 0), maxGraceMs)
	}

	private func computeMoleWindowMs(baseUpTimeMs: Int, speechDurationMs: Int) -> Int {
		let reactionBufferMs = 260
		let minUpTimeMs = 400
		let maxUpTimeMs = 1800
		let effectiveSpeechDurationMs = max(300, speechDurationMs)

		return min(
			max(baseUpTimeMs + effectiveSpeechDurationMs + reactionBufferMs, minUpTimeMs),
			maxUpTimeMs
		)
	}

	private func getProgress() -> Double {
		let elapsedMs = TimeUtils.nowMs() - roundStartTimeMs
		var progress = min(Double(elapsedMs) / Double(roundDurationMs), 1.0)

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
		var intervalMs = TimeUtils.lerp(start: startIntervalMs, end: endIntervalMs, t: getProgress())

		if getProgress() > 0.7 {
			intervalMs = Int(Double(intervalMs) * 0.45)
		}

		intervalMs += Int.random(in: 0..<120)

		return max(Int(Double(intervalMs) * difficultyMultiplier), 180)
	}

	private func getCurrentUpTime() -> Int {
		let baseUpTimeMs = TimeUtils.lerp(start: startUpTimeMs, end: endUpTimeMs, t: getProgress())
		return Int(Double(baseUpTimeMs) * difficultyMultiplier)
	}

	private func scheduleNextMole(extraDelayMs: Int) {
		guard isRunning, !roundEnding else { return }

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(getCurrentInterval() + extraDelayMs))
		timer.setEventHandler { [weak self] in
			self?.showRandomMole()
		}
		timer.resume()

		moleTimer?.cancel()
		moleTimer = timer
	}

	private func showRandomMole() {
		guard isRunning, !roundEnding else { return }
		guard !roundItems.isEmpty else { return }

		clearActiveMole()

		activeMoleId += 1
		missRegisteredForMole = false

		let lane = pickNextMoleIndex()
		let item = roundItems[lane]
		let moleId = activeMoleId
		let speechDurationMs = SpeechEngine.shared.estimatedDurationMs(for: item.announceText)

		activeMoleIndex = lane
		activeMoleUpTimeMs = computeMoleWindowMs(
			baseUpTimeMs: getCurrentUpTime(),
			speechDurationMs: speechDurationMs
		)

		SpeechEngine.shared.speak(item.announceText)

		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80)) { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding else { return }
			guard self.activeMoleId == moleId, self.activeMoleIndex == lane else { return }

			self.moleBecameActiveMs = TimeUtils.nowMs()
			self.onActiveMoleChanged?(lane, item)
			GameAudioEngine.shared.playMolePop(lane: lane)
		}

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(activeMoleUpTimeMs))
		timer.setEventHandler { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding else { return }
			guard self.activeMoleId == moleId, self.activeMoleIndex == lane else { return }

			self.escapesThisRound += 1
			self.hitStreak = 0
			self.onScoreUpdated?(self.score, self.hitStreak)
			GameAudioEngine.shared.playRetreat(lane: lane)

			self.clearActiveMole()
			self.scheduleNextMole(extraDelayMs: 0)
		}
		timer.resume()

		moleUpTimer?.cancel()
		moleUpTimer = timer
	}

	private func pickNextMoleIndex() -> Int {
		guard !roundItems.isEmpty else { return 0 }
		guard roundItems.count > 1 else { return 0 }

		var candidates = Array(roundItems.indices).filter { $0 != activeMoleIndex }

		if let lastLaneIndex, sameLaneRunCount >= maxSameLaneInRow {
			let nonRepeatingCandidates = candidates.filter { $0 != lastLaneIndex }
			if !nonRepeatingCandidates.isEmpty {
				candidates = nonRepeatingCandidates
			}
		}

		let lane = candidates.randomElement() ?? 0

		if lane == lastLaneIndex {
			sameLaneRunCount += 1
		} else {
			lastLaneIndex = lane
			sameLaneRunCount = 1
		}

		return lane
	}

	private func buildRoundItems(from pool: [BrailleItem]) -> [BrailleItem] {
		guard !pool.isEmpty else { return [] }

		var copy = pool
		copy.shuffle()

		if copy.count >= laneCount {
			return Array(copy.prefix(laneCount))
		}

		var padded = copy
		var index = 0

		while padded.count < laneCount {
			padded.append(copy[index % copy.count])
			index += 1
		}

		return padded
	}

	private func clearActiveMole() {
		activeMoleIndex = nil
		moleBecameActiveMs = 0
		onActiveMoleChanged?(nil, nil)
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

	private func normalize(_ string: String?) -> String {
		String(string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
	}
}

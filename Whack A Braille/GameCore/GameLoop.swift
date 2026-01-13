import Foundation

final class GameLoop {

	// MARK: - State

	private(set) var isRunning: Bool = false
	private(set) var roundEnding: Bool = false

	private var roundDurationMs: Int = 30_000
	private var roundStartTimeMs: Int = 0

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

	// MARK: - Mole State

	private var activeMoleIndex: Int? = nil
	private var activeMoleId: Int = 0
	private var missRegisteredForMole: Bool = false
	private var activeMoleShownAtMs: Int = 0
	private var activeMoleUpTimeMs: Int = 0

	// MARK: - Timers

	private var roundTimer: DispatchSourceTimer?
	private var moleTimer: DispatchSourceTimer?
	private var moleUpTimer: DispatchSourceTimer?

	// MARK: - Configuration

	private let startIntervalMs: Int = 900
	private let endIntervalMs: Int = 300
	private let startUpTimeMs: Int = 650
	private let endUpTimeMs: Int = 250

	private let difficultyMultipliers: [Difficulty: Double] = [
		.beginner: 1.5,
		.normal: 1.0,
		.supreme: 0.5
	]

	private var difficultyMultiplier: Double = 1.0

	// MARK: - Data

	private var availableItems: [BrailleItem] = []
	private var roundItems: [BrailleItem] = []

	private var currentModeId: String = ""
	private var currentInputMode: InputMode = .qwerty
	private var currentDurationSeconds: Int = 30

	// MARK: - Callbacks

	var onRoundEnded: ((RoundResult) -> Void)?
	var onScoreUpdated: ((Int, Int) -> Void)?

	init() {}
	
	// MARK: - Round Control

	func handleAttempt(_ attempt: Attempt) {
		if !isRunning || roundEnding {
			return
		}

		guard let activeIndex = activeMoleIndex else {
			return
		}

		if attempt.moleId != activeMoleId {
			return
		}

		// Perkins mode ignores standard keyboard attempts
		if currentInputMode == .perkins && attempt.type == .qwerty {
			return
		}

		let currentItem = roundItems[activeIndex]
		var isHit = false

		switch attempt.type {
		case .perkins:
			if let mask = attempt.dotMask {
				isHit = mask == currentItem.dotMask
			}

		case .qwerty:
			if
				let a = attempt.key?.lowercased(),
				let b = currentItem.standardKey?.lowercased()
			{
				isHit = a == b
			}

		case .brailleText:
			if let c = attempt.char?.lowercased() {
				isHit = c == currentItem.id.lowercased()
			}
		}

		if isHit {
			handleHit()
			return
		}

		if missRegisteredForMole {
			return
		}

		missRegisteredForMole = true
		handleMiss()
	}

	private func handleHit() {
		hitsThisRound += 1
		hitStreak += 1
		score += 10

		if hitStreak % 5 == 0 {
			score += 10
			streakBonusCount += 1
		}

		let nowMs = TimeUtils.nowMs()
		let reactionMs = nowMs - activeMoleShownAtMs
		let speedThresholdMs = Int(Double(activeMoleUpTimeMs) * 0.55)

		if reactionMs <= speedThresholdMs {
			speedHitCount += 1

			if speedHitCount % 3 == 0 && speedBonusTickets < 5 {
				speedBonusTickets += 1
			}
		}

		moleUpTimer?.cancel()
		moleUpTimer = nil

		missRegisteredForMole = true

		clearActiveMole()
		scheduleNextMole(extraDelayMs: 0)

		onScoreUpdated?(score, hitStreak)
	}

	private func handleMiss() {
		missesThisRound += 1
		hitStreak = 0
		score = max(0, score - 2)

		onScoreUpdated?(score, hitStreak)
	}

	func startRound(
		modeId: String,
		durationSeconds: Int,
		inputMode: InputMode,
		difficulty: Difficulty = .normal,
		itemsForMode: [BrailleItem]
	) {
		if isRunning {
			return
		}

		score = 0
		hitStreak = 0
		hitsThisRound = 0
		missesThisRound = 0
		escapesThisRound = 0
		streakBonusCount = 0
		speedHitCount = 0
		speedBonusTickets = 0

		currentModeId = modeId
		currentDurationSeconds = durationSeconds
		currentInputMode = modeId == "everything" ? .perkins : inputMode
		difficultyMultiplier = difficultyMultipliers[difficulty] ?? 1.0

		roundDurationMs = durationSeconds * 1000
		availableItems = itemsForMode
		roundItems = pickFiveItems(from: availableItems)

		isRunning = true
		roundEnding = false

		roundStartTimeMs = TimeUtils.nowMs()

		activeMoleIndex = nil
		activeMoleId = 0
		missRegisteredForMole = false

		cancelTimers()
		scheduleRoundEnd()
		scheduleNextMole(extraDelayMs: 0)
	}

	func stopRound() {
		endRoundNow(canceled: true)
	}

	private func computeRoundEndGraceMs(
		baseGraceMs: Int,
		maxGraceMs: Int
	) -> Int {
		// JS behavior: random value between base and max
		let range = maxGraceMs - baseGraceMs
		if range <= 0 {
			return baseGraceMs
		}

		return baseGraceMs + Int.random(in: 0...range)
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
		if !isRunning {
			return
		}

		roundEnding = true

		moleTimer?.cancel()
		moleTimer = nil

		let graceMs = computeRoundEndGraceMs(
			baseGraceMs: 350,
			maxGraceMs: 750
		)

		roundTimer?.cancel()

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(graceMs))
		timer.setEventHandler { [weak self] in
			self?.endRoundNow(canceled: false)
		}
		timer.resume()
		roundTimer = timer
	}

	private func endRoundNow(canceled: Bool) {
		if !isRunning {
			return
		}

		isRunning = false
		roundEnding = false

		cancelTimers()
		clearActiveMole()

		let baseTickets = scoreToTickets(score)

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
			baseTickets: baseTickets,
			streakBonusTickets: streakBonusCount,
			speedBonusTickets: speedBonusTickets
		)

		onRoundEnded?(result)
	}

	// MARK: - Timing Math

	private func getProgress() -> Double {
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
		var interval = TimeUtils.lerp(
			start: startIntervalMs,
			end: endIntervalMs,
			t: getProgress()
		)

		if getProgress() > 0.7 {
			interval = Int(Double(interval) * 0.45)
		}

		let adjusted = Int(Double(interval) * difficultyMultiplier)
		return max(adjusted, 180)
	}

	private func getCurrentUpTime() -> Int {
		let base = TimeUtils.lerp(
			start: startUpTimeMs,
			end: endUpTimeMs,
			t: getProgress()
		)
		return Int(Double(base) * difficultyMultiplier)
	}

	private func pickNextMoleIndex() -> Int {
		guard !roundItems.isEmpty else {
			return 0
		}

		var index: Int
		repeat {
			index = Int.random(in: 0..<roundItems.count)
		} while index == activeMoleIndex

		return index
	}

	private func showRandomMole() {
		if !isRunning || roundEnding {
			return
		}

		clearActiveMole()

		activeMoleId += 1
		missRegisteredForMole = false

		let index = pickNextMoleIndex()
		activeMoleIndex = index

		let thisMoleId = activeMoleId
		let upTime = getCurrentUpTime()
		activeMoleUpTimeMs = upTime

		activeMoleShownAtMs = TimeUtils.nowMs()

		// Escape timer (JS moleUpTimer)
		moleUpTimer?.cancel()

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(upTime))
		timer.setEventHandler { [weak self] in
			guard let self else { return }
			if !self.isRunning || self.roundEnding { return }
			if thisMoleId != self.activeMoleId { return }

			self.escapesThisRound += 1
			self.hitStreak = 0

			self.clearActiveMole()
			self.scheduleNextMole(extraDelayMs: 0)
		}
		timer.resume()

		moleUpTimer = timer
	}

	private func randomJitter() -> Int {
		Int.random(in: 0..<120)
	}

	private func scheduleNextMole(extraDelayMs: Int) {
		if !isRunning || roundEnding {
			return
		}

		let delayMs = getCurrentInterval() + randomJitter() + extraDelayMs

		moleTimer?.cancel()

		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(delayMs))
		timer.setEventHandler { [weak self] in
			self?.showRandomMole()
		}
		timer.resume()

		moleTimer = timer
	}

	// MARK: - Utilities

	private func pickFiveItems(from pool: [BrailleItem]) -> [BrailleItem] {
		var copy = pool
		copy.shuffle()
		return Array(copy.prefix(5))
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
	private func clearActiveMole() {
		activeMoleIndex = nil
	}

}

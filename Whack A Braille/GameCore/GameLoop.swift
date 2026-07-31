import Foundation

@MainActor
final class GameLoop {

	enum FeedbackKind {
		case hit
		case miss
	}

	struct ActiveBlitzMole: Identifiable, Equatable {
		let index: Int
		let letter: String
		let pan: Float
		let isWhacked: Bool

		var id: Int { index }
	}

	enum TrainingIntroKind {
		case standard
		case moleRecon
		case grudgeMatch
	}

	struct Options {
		let modeId: String
		let durationSeconds: Int
		let inputMode: InputMode
		let difficulty: Difficulty
		let speakBrailleDots: Bool
		let spellBlitzWords: Bool
		let characterEcho: Bool
		let timerMusicEnabled: Bool
		let spatialMoleMappingEnabled: Bool
		let customMolePlayMode: CustomMolePlayMode
		let customMoleIDs: [String]
		let trainingIntroKind: TrainingIntroKind
		let customBlitzWords: [String]

		init(
			modeId: String,
			durationSeconds: Int,
			inputMode: InputMode,
			difficulty: Difficulty,
			speakBrailleDots: Bool,
			characterEcho: Bool,
			timerMusicEnabled: Bool,
			spatialMoleMappingEnabled: Bool,
			customMolePlayMode: CustomMolePlayMode,
			customMoleIDs: [String],
			trainingIntroKind: TrainingIntroKind,
			spellBlitzWords: Bool = false,
			customBlitzWords: [String] = []
		) {
			self.modeId = modeId
			self.durationSeconds = durationSeconds
			self.inputMode = inputMode
			self.difficulty = difficulty
			self.speakBrailleDots = speakBrailleDots
			self.spellBlitzWords = spellBlitzWords
			self.characterEcho = characterEcho
			self.timerMusicEnabled = timerMusicEnabled
			self.spatialMoleMappingEnabled = spatialMoleMappingEnabled
			self.customMolePlayMode = customMolePlayMode
			self.customMoleIDs = customMoleIDs
			self.trainingIntroKind = trainingIntroKind
			self.customBlitzWords = customBlitzWords
		}
	}

	var onRoundEnded: ((RoundResult) -> Void)?
	var onScoreUpdated: ((Int, Int) -> Void)?
	var onActiveMoleChanged: ((Int?, BrailleItem?) -> Void)?
	var onActiveBlitzMolesChanged: (([ActiveBlitzMole]) -> Void)?
	var onInputResetRequested: (() -> Void)?
	var onMoleFeedback: ((Int, FeedbackKind) -> Void)?

	private(set) var isRunning: Bool = false
	private(set) var roundEnding: Bool = false
	private(set) var score: Int = 0
	private(set) var hitStreak: Int = 0
	private(set) var currentMoleId: Int = 0

	private let laneCount = 5
	private let maxSameLaneInRow = 2
	private let trainingMoleCap = 15
	private let trainingFirstMoleDelayMs = 650
	private let trainingPostHitDelayMs = 750
	private let blitzCompletionSoundDelayMs = 80
	private let blitzCompletionMinimumTransitionDelayMs = 650

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
		spatialMoleMappingEnabled: true,
		customMolePlayMode: .individual,
		customMoleIDs: [],
		trainingIntroKind: .standard
	)

	private var availableItems: [BrailleItem] = []
	private var roundItems: [BrailleItem] = []
	private var roundLaneItems: [BrailleItem?] = []
	private var invasionActiveItem: BrailleItem?
	private var availableBlitzWords: [BlitzWord] = []
	private var activeBlitzWord: BlitzWord?
	private var activeBlitzLetterIndex = 0
	private var availableWordyMoleMayhemWords: [WordyMoleMayhemEntry] = []
	private var activeWordyMoleMayhemWord: WordyMoleMayhemEntry?

	private var activeLane: Int?
	private var missRegisteredForMole = false
	private var activeMoleShownAtMs = 0
	private var activeMoleUpTimeMs = 0

	private var hitsThisRound = 0
	private var missesThisRound = 0
	private var escapesThisRound = 0
	private var bestStreakThisRound = 0
	private var streakBonusCount = 0
	private var speedHitCount = 0
	private var speedBonusTickets = 0
	private var trainingMolesCompleted = 0
	private var lettersWhackedThisRound = 0
	private var lastTrainingMissAtMs = 0
	private var moleReconItems: [BrailleItem] = []
	private var moleReconItemIDs = Set<String>()
	private var shownMoleReconItems: [BrailleItem] = []
	private var shownMoleReconItemIDs = Set<String>()

	private var roundDurationMs = 30_000
	private var roundStartTimeMs = 0
	private var lastLaneIndex: Int?
	private var sameLaneRunCount = 0
	private var lastItemID: String?
	private var sameItemRunCount = 0
	private var pendingTextTokens: [String] = []
	private var pendingPerkinsMasks: [Int] = []
	private var lastBlitzWord: String?

	private var roundTimer: DispatchSourceTimer?
	private var moleTimer: DispatchSourceTimer?
	private var moleUpTimer: DispatchSourceTimer?

	func startRound(options: Options) {
		guard !isRunning else { return }

		currentOptions = options
		availableItems = items(for: options)
		availableBlitzWords = BlitzWordCatalog.words(
			for: options.modeId,
			customWords: options.customBlitzWords
		)
		availableWordyMoleMayhemWords = WordyMoleMayhemCatalog.words(
			for: options.modeId,
			customWords: options.customBlitzWords
		)
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
		bestStreakThisRound = 0
		streakBonusCount = 0
		speedHitCount = 0
		speedBonusTickets = 0
		trainingMolesCompleted = 0
		lettersWhackedThisRound = 0
		lastTrainingMissAtMs = 0
		moleReconItems = []
		moleReconItemIDs = []
		shownMoleReconItems = []
		shownMoleReconItemIDs = []

		roundDurationMs = options.durationSeconds * 1000
		roundStartTimeMs = TimeUtils.nowMs()
		lastLaneIndex = nil
		sameLaneRunCount = 0
		lastItemID = nil
		sameItemRunCount = 0
		activeLane = nil
		invasionActiveItem = nil
		activeBlitzWord = nil
		activeBlitzLetterIndex = 0
		activeWordyMoleMayhemWord = nil
		currentMoleId = 0
		missRegisteredForMole = false
		activeMoleShownAtMs = 0
		activeMoleUpTimeMs = 0
		pendingTextTokens = []
		pendingPerkinsMasks = []
		lastBlitzWord = nil

		isRunning = true
		roundEnding = false

		cancelTimers()
		onScoreUpdated?(score, hitStreak)
		onActiveMoleChanged?(nil, nil)
		onActiveBlitzMolesChanged?([])

		GameAudioEngine.shared.startRoundAudio(
			progressProvider: { [weak self] in
				self?.getProgress() ?? 0
			},
			timerMusicEnabled: options.timerMusicEnabled && options.difficulty != .training
		)

		if options.difficulty == .training {
			scheduleNextTrainingMole(extraDelayMs: trainingFirstMoleDelayMs)
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
		if let activeBlitzWord {
			SpeechEngine.shared.speak(buildBlitzAnnounceText(for: activeBlitzWord), interrupt: true)
			return
		}
		if let activeWordyMoleMayhemWord {
			SpeechEngine.shared.speak(buildWordyMoleMayhemAnnounceText(for: activeWordyMoleMayhemWord), interrupt: true)
			return
		}
		guard let item = currentItem else { return }
		SpeechEngine.shared.speak(buildAnnounceText(for: item), interrupt: true)
	}

	func setSpeakBrailleDots(_ enabled: Bool) {
		currentOptions = Options(
			modeId: currentOptions.modeId,
			durationSeconds: currentOptions.durationSeconds,
			inputMode: currentOptions.inputMode,
			difficulty: currentOptions.difficulty,
			speakBrailleDots: enabled,
			characterEcho: currentOptions.characterEcho,
			timerMusicEnabled: currentOptions.timerMusicEnabled,
			spatialMoleMappingEnabled: currentOptions.spatialMoleMappingEnabled,
			customMolePlayMode: currentOptions.customMolePlayMode,
			customMoleIDs: currentOptions.customMoleIDs,
			trainingIntroKind: currentOptions.trainingIntroKind,
			spellBlitzWords: currentOptions.spellBlitzWords,
			customBlitzWords: currentOptions.customBlitzWords
		)
	}

	func handleAttempt(_ attempt: Attempt) {
		guard isRunning, !roundEnding || activeBlitzWord != nil || activeWordyMoleMayhemWord != nil else { return }
		if activeBlitzWord != nil {
			handleBlitzAttempt(attempt)
			return
		}
		if activeWordyMoleMayhemWord != nil {
			handleWordyMoleMayhemAttempt(attempt)
			return
		}
		guard let activeLane, let currentItem = laneItem(for: activeLane) else { return }
		guard attempt.moleId == currentMoleId else { return }
		guard attempt.key != "`" else {
			repeatCurrentTarget()
			return
		}

		if currentOptions.inputMode == .perkins && attempt.type == .qwerty {
			return
		}

		switch attempt.type {
		case .perkins:
			handlePerkinsAttempt(attempt.dotMask, currentItem: currentItem)
		case .qwerty:
			handleTextAttemptToken(normalize(attempt.key), currentItem: currentItem)
		case .brailleText:
			handleSubmittedText(normalize(attempt.char), currentItem: currentItem)
		case .brailleDisplayInput:
			handleSubmittedText(normalize(attempt.char), currentItem: currentItem)
		case .oneHandedBrailleInput:
			handleSubmittedText(normalize(attempt.char), currentItem: currentItem)
		}
	}

	private var currentItem: BrailleItem? {
		if isInvasionMode {
			return invasionActiveItem
		}
		guard let activeLane else { return nil }
		return laneItem(for: activeLane)
	}

	private func laneItem(for lane: Int) -> BrailleItem? {
		if isInvasionMode, lane == activeLane {
			return invasionActiveItem
		}
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
		let rawBaseTickets = isTraining ? 0 : scoreToTickets(score)
		let rawStreakTickets = isTraining ? 0 : streakBonusCount
		let rawSpeedTickets = isTraining ? 0 : speedBonusTickets
		let baseTickets = adjustedTickets(rawBaseTickets)
		let streakTickets = adjustedTickets(rawStreakTickets)
		let speedTickets = adjustedTickets(rawSpeedTickets)
		let usesAllShownMolesForRecon = !isTraining && moleReconItems.isEmpty && !shownMoleReconItems.isEmpty

		onRoundEnded?(
			RoundResult(
				modeId: currentOptions.modeId,
				inputMode: effectiveInputMode,
				durationSeconds: currentOptions.durationSeconds,
				isTraining: isTraining,
				trainingMolesCompleted: trainingMolesCompleted,
				isBlitzMode: isWordMode,
				lettersWhacked: lettersWhackedThisRound,
				score: score,
				hits: hitsThisRound,
				misses: missesThisRound,
				escapes: escapesThisRound,
				bestStreak: bestStreakThisRound,
				streakBonusCount: streakBonusCount,
				canceled: canceled,
				moleReconItems: moleReconItems,
				grudgeMatchItems: shownMoleReconItems,
				usesAllShownMolesForRecon: usesAllShownMolesForRecon,
				baseTickets: baseTickets,
				streakBonusTickets: streakTickets,
				speedBonusTickets: speedTickets
			)
		)
	}

	private var effectiveInputMode: InputMode {
		currentOptions.inputMode
	}

	private func scheduleNextMole(extraDelayMs: Int, minimumDelayMs: Int = 0) {
		guard isRunning, !roundEnding else { return }

		let normalDelay = getCurrentInterval() + Int.random(in: 0..<120) + extraDelayMs
		let delay = max(normalDelay, minimumDelayMs)
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

		if isWordyMoleMayhemMode {
			showWordyMoleMayhemWord(trainingMode: trainingMode)
			return
		}

		if isGrade1BattleMode {
			showBlitzWord(trainingMode: trainingMode)
			return
		}

		let lane = pickNextLaneIndex()
		let item: BrailleItem?

		if isInvasionMode {
			item = pickNextInvasionItem()
			invasionActiveItem = item
		} else {
			item = laneItem(for: lane)
		}

		guard let item else {
			clearActiveMole()
			scheduleFollowUp(afterTraining: trainingMode)
			return
		}
		if !trainingMode {
			recordShownMoleReconItem(item)
		}

		let moleId = currentMoleId
		activeLane = lane
		onActiveMoleChanged?(nil, nil)

		let announceText = buildAnnounceText(for: item)
		let speechDurationMs = SpeechEngine.shared.estimatedDurationMs(for: announceText)
		let baseUpTimeMs = trainingMode ? 0 : getCurrentUpTime()
		let moleRevealDelayMs = 140

		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(moleRevealDelayMs)) { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding else { return }
			guard self.currentMoleId == moleId, self.activeLane == lane else { return }

			self.activeMoleShownAtMs = TimeUtils.nowMs()
			self.onActiveMoleChanged?(lane, item)
			GameAudioEngine.shared.playMolePop(lane: lane)
			self.playGameplaySpeech(announceText)
		}

		if trainingMode {
			activeMoleUpTimeMs = 0
			return
		}

		activeMoleUpTimeMs = computeMoleWindowMs(
			item: item,
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
			self.recordMoleReconItem(item)
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

	private func showBlitzWord(trainingMode: Bool) {
		guard let word = pickNextBlitzWord() else {
			scheduleFollowUp(afterTraining: trainingMode)
			return
		}

		activeBlitzWord = word
		activeBlitzLetterIndex = 0
		activeLane = 0
		let moleId = currentMoleId
		let wordItem = word.asBrailleItem(modeId: currentOptions.modeId)

		if !trainingMode, let wordItem {
			recordShownMoleReconItem(wordItem)
		}

		let announceText = buildBlitzAnnounceText(for: word)
		let speechDurationMs = SpeechEngine.shared.estimatedDurationMs(for: announceText)
		let revealDelayMs = 140

		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(revealDelayMs)) { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding else { return }
			guard self.currentMoleId == moleId, self.activeBlitzWord == word else { return }

			self.activeMoleShownAtMs = TimeUtils.nowMs()
			self.publishActiveBlitzMoles()
			GameAudioEngine.shared.playBlitzWordPop(wordLength: word.length)
			self.playGameplaySpeech(announceText)
		}

		if trainingMode {
			activeMoleUpTimeMs = 0
			return
		}

		activeMoleUpTimeMs = computeBlitzWindowMs(word: word, speechDurationMs: speechDurationMs)
		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(activeMoleUpTimeMs))
		timer.setEventHandler { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding else { return }
			guard self.currentMoleId == moleId, self.activeBlitzWord == word else { return }

			self.escapesThisRound += 1
			if let wordItem {
				self.recordMoleReconItem(wordItem)
			}
			self.hitStreak = 0
			self.onScoreUpdated?(self.score, self.hitStreak)
			self.onInputResetRequested?()

			for index in self.activeBlitzLetterIndex..<word.length {
				GameAudioEngine.shared.playRetreat(
					pan: BlitzWord.pan(forLetterAt: index, wordLength: word.length)
				)
			}

			self.clearActiveMole()
			self.scheduleNextMole(extraDelayMs: 0)
		}
		timer.resume()

		moleUpTimer?.cancel()
		moleUpTimer = timer
	}

	private func handleBlitzAttempt(_ attempt: Attempt) {
		guard let word = activeBlitzWord else { return }
		guard activeMoleShownAtMs > 0 else { return }
		guard attempt.moleId == currentMoleId else { return }
		guard attempt.key != "`" else {
			repeatCurrentTarget()
			return
		}

		switch attempt.type {
		case .perkins:
			guard let mask = attempt.dotMask,
				let expectedItem = expectedBlitzLetterItem(in: word)
			else { return }
			resolveBlitzLetter(mask == expectedItem.dotMask)
		case .qwerty:
			handleBlitzSubmittedText(normalize(attempt.key))
		case .brailleText, .brailleDisplayInput, .oneHandedBrailleInput:
			handleBlitzSubmittedText(normalize(attempt.char))
		}
	}

	private func handleBlitzSubmittedText(_ input: String) {
		guard let word = activeBlitzWord, !input.isEmpty else { return }
		guard input.allSatisfy(\.isLetter) else {
			resolveBlitzLetter(false)
			return
		}
		let submittedLetters = Array(input)

		let remainingLetters = Array(word.letters.dropFirst(activeBlitzLetterIndex))
		guard submittedLetters.count <= remainingLetters.count,
			Array(remainingLetters.prefix(submittedLetters.count)) == submittedLetters
		else {
			resolveBlitzLetter(false)
			return
		}

		let usesSingleSubmissionSound = currentOptions.inputMode.usesBufferedTextEntry
		let scoreBeforeSubmission = score
		for _ in submittedLetters {
			guard activeBlitzWord != nil else { break }
			handleBlitzLetterHit(
				playsSound: !usesSingleSubmissionSound,
				completionScoreBaseline: usesSingleSubmissionSound ? scoreBeforeSubmission : nil
			)
		}
	}

	private func resolveBlitzLetter(_ hit: Bool) {
		if hit {
			handleBlitzLetterHit()
			return
		}

		guard let word = activeBlitzWord else { return }
		let pan = BlitzWord.pan(forLetterAt: activeBlitzLetterIndex, wordLength: word.length)
		GameAudioEngine.shared.playMiss(pan: pan)
		onMoleFeedback?(activeBlitzLetterIndex, .miss)

		if currentOptions.difficulty != .training, !missRegisteredForMole {
			missRegisteredForMole = true
			missesThisRound += 1
			if let item = word.asBrailleItem(modeId: currentOptions.modeId) {
				recordMoleReconItem(item)
			}
			hitStreak = 0
			score = max(0, score - 2)
			onScoreUpdated?(score, hitStreak)
		}

		onInputResetRequested?()
	}

	private func handleBlitzLetterHit(
		playsSound: Bool = true,
		completionScoreBaseline: Int? = nil
	) {
		guard let word = activeBlitzWord, activeBlitzLetterIndex < word.length else { return }
		let hitIndex = activeBlitzLetterIndex
		let pan = BlitzWord.pan(forLetterAt: hitIndex, wordLength: word.length)
		let scoreBeforeHit = score

		lettersWhackedThisRound += 1
		activeBlitzLetterIndex += 1

		if currentOptions.difficulty != .training {
			score += 10
		}

		if playsSound {
			GameAudioEngine.shared.playHit(scoreBeforeHit: scoreBeforeHit, pan: pan)
		}
		onMoleFeedback?(hitIndex, .hit)
		publishActiveBlitzMoles()

		guard activeBlitzLetterIndex >= word.length else {
			onScoreUpdated?(score, hitStreak)
			return
		}

		finishBlitzWord(
			word,
			completionScoreBaseline: completionScoreBaseline ?? score,
			completionSoundDelayMs: playsSound ? blitzCompletionSoundDelayMs : 0
		)
	}

	private func finishBlitzWord(
		_ word: BlitzWord,
		completionScoreBaseline: Int,
		completionSoundDelayMs: Int
	) {
		moleUpTimer?.cancel()
		moleUpTimer = nil
		hitsThisRound += 1
		onInputResetRequested?()

		if currentOptions.difficulty == .training {
			trainingMolesCompleted += 1
			playBlitzCompletionSound(
				wordLength: word.length,
				scoreBeforeHit: completionScoreBaseline,
				scoreAfterHit: score,
				delayMs: completionSoundDelayMs
			)
			clearActiveMole()
			scheduleNextTrainingMole(extraDelayMs: trainingPostHitDelayMs)
			return
		}

		hitStreak += 1
		bestStreakThisRound = max(bestStreakThisRound, hitStreak)
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

		playBlitzCompletionSound(
			wordLength: word.length,
			scoreBeforeHit: completionScoreBaseline,
			scoreAfterHit: score,
			delayMs: completionSoundDelayMs
		)
		clearActiveMole()
		onScoreUpdated?(score, hitStreak)
		scheduleNextMole(
			extraDelayMs: 0,
			minimumDelayMs: blitzCompletionMinimumTransitionDelayMs
		)
	}

	private func playBlitzCompletionSound(
		wordLength: Int,
		scoreBeforeHit: Int,
		scoreAfterHit: Int,
		delayMs: Int
	) {
		let playSound = {
			GameAudioEngine.shared.playBlitzWordHit(
				wordLength: wordLength,
				scoreBeforeHit: scoreBeforeHit,
				scoreAfterHit: scoreAfterHit
			)
		}

		guard delayMs > 0 else {
			playSound()
			return
		}

		let completedMoleId = currentMoleId
		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding, self.currentMoleId == completedMoleId else { return }
			playSound()
		}
	}

	private func publishActiveBlitzMoles() {
		guard let word = activeBlitzWord else {
			onActiveBlitzMolesChanged?([])
			return
		}

		let moles = word.letters.enumerated().map { index, letter in
			ActiveBlitzMole(
				index: index,
				letter: String(letter),
				pan: BlitzWord.pan(forLetterAt: index, wordLength: word.length),
				isWhacked: index < activeBlitzLetterIndex
			)
		}
		onActiveBlitzMolesChanged?(moles)
	}

	private func expectedBlitzLetterItem(in word: BlitzWord) -> BrailleItem? {
		guard word.letters.indices.contains(activeBlitzLetterIndex) else { return nil }
		let expectedLetter = String(word.letters[activeBlitzLetterIndex])
		return BrailleRegistry.grade1Letters.first { $0.id == expectedLetter }
	}

	private func pickNextBlitzWord() -> BlitzWord? {
		guard !availableBlitzWords.isEmpty else { return nil }
		let candidates = availableBlitzWords.filter { $0.text != lastBlitzWord }
		let word = candidates.randomElement() ?? availableBlitzWords.randomElement()
		lastBlitzWord = word?.text
		return word
	}

	private func computeBlitzWindowMs(word: BlitzWord, speechDurationMs: Int) -> Int {
		let perLetterMs: Int
		switch currentOptions.inputMode {
		case .qwerty:
			perLetterMs = 620
		case .perkins:
			perLetterMs = 780
		case .brailleText, .brailleDisplayInput:
			perLetterMs = 860
		case .oneHandedBrailleInput:
			perLetterMs = 1_150
		}

		let difficultyMultiplier = difficultyMultipliers[currentOptions.difficulty] ?? 1.0
		let entryTimeMs = Int(Double(perLetterMs * word.length) * difficultyMultiplier)
		let minimumMs = currentOptions.inputMode == .oneHandedBrailleInput ? 4_500 : 2_400
		let maximumMs = currentOptions.inputMode == .oneHandedBrailleInput ? 12_000 : 8_000
		return min(max(speechDurationMs + entryTimeMs + 450, minimumMs), maximumMs)
	}

	private func buildBlitzAnnounceText(for word: BlitzWord) -> String {
		var announcementParts = [word.text]
		if currentOptions.spellBlitzWords {
			announcementParts.append(word.letters.map(String.init).joined(separator: " "))
		}

		guard currentOptions.difficulty == .training, currentOptions.speakBrailleDots else {
			return announcementParts.joined(separator: ", ")
		}

		let letterByID = Dictionary(uniqueKeysWithValues: BrailleRegistry.grade1Letters.map { ($0.id, $0) })
		let patterns = word.letters.compactMap { letterByID[String($0)]?.dots }
		let dotPattern = BrailleItem.compactDotPatternText(for: patterns)
		if !dotPattern.isEmpty {
			announcementParts.append(dotPattern)
		}
		return announcementParts.joined(separator: ", ")
	}

	private func showWordyMoleMayhemWord(trainingMode: Bool) {
		guard let word = pickNextWordyMoleMayhemWord(), let wordItem = word.asBrailleItem() else {
			scheduleFollowUp(afterTraining: trainingMode)
			return
		}

		let lane = laneCount / 2
		activeWordyMoleMayhemWord = word
		activeLane = lane
		let moleId = currentMoleId

		if !trainingMode {
			recordShownMoleReconItem(wordItem)
		}

		let announceText = buildWordyMoleMayhemAnnounceText(for: word)
		let speechDurationMs = SpeechEngine.shared.estimatedDurationMs(for: announceText)
		let revealDelayMs = 140

		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(revealDelayMs)) { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding else { return }
			guard self.currentMoleId == moleId, self.activeWordyMoleMayhemWord == word else { return }

			self.activeMoleShownAtMs = TimeUtils.nowMs()
			self.onActiveMoleChanged?(lane, wordItem)
			GameAudioEngine.shared.playMolePop(lane: lane)
			self.playGameplaySpeech(announceText)
		}

		if trainingMode {
			activeMoleUpTimeMs = 0
			return
		}

		activeMoleUpTimeMs = computeWordyMoleMayhemWindowMs(word: word, speechDurationMs: speechDurationMs)
		let timer = DispatchSource.makeTimerSource(queue: .main)
		timer.schedule(deadline: .now() + .milliseconds(activeMoleUpTimeMs))
		timer.setEventHandler { [weak self] in
			guard let self else { return }
			guard self.isRunning, !self.roundEnding else { return }
			guard self.currentMoleId == moleId, self.activeWordyMoleMayhemWord == word else { return }

			self.escapesThisRound += 1
			self.recordMoleReconItem(wordItem)
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

	private func handleWordyMoleMayhemAttempt(_ attempt: Attempt) {
		guard let word = activeWordyMoleMayhemWord else { return }
		guard activeMoleShownAtMs > 0 else { return }
		guard attempt.moleId == currentMoleId else { return }
		guard attempt.key != "`" else {
			repeatCurrentTarget()
			return
		}
		if currentOptions.inputMode == .perkins, attempt.type != .perkins {
			return
		}

		switch attempt.type {
		case .perkins:
			guard let mask = attempt.dotMask else { return }
			handleWordyMoleMayhemPerkinsCell(mask, word: word)
		case .qwerty:
			handleWordyMoleMayhemTextToken(normalize(attempt.key), word: word)
		case .brailleText, .brailleDisplayInput, .oneHandedBrailleInput:
			resolveWordyMoleMayhemAttempt(normalize(attempt.char) == word.text, word: word)
		}
	}

	private func handleWordyMoleMayhemPerkinsCell(_ mask: Int, word: WordyMoleMayhemEntry) {
		let updatedSequence = pendingPerkinsMasks + [mask]
		let sequences = word.acceptedPerkinsSequences

		if sequences.contains(updatedSequence) {
			pendingPerkinsMasks.removeAll()
			resolveWordyMoleMayhemAttempt(true, word: word)
			return
		}

		if sequences.contains(where: { $0.starts(with: updatedSequence) }) {
			pendingPerkinsMasks = updatedSequence
			return
		}

		pendingPerkinsMasks.removeAll()
		resolveWordyMoleMayhemAttempt(false, word: word)
	}

	private func handleWordyMoleMayhemTextToken(_ token: String, word: WordyMoleMayhemEntry) {
		guard token.count == 1, token.first?.isLetter == true else {
			pendingTextTokens.removeAll()
			resolveWordyMoleMayhemAttempt(false, word: word)
			return
		}

		let updatedTokens = pendingTextTokens + [token]
		let expectedTokens = word.text.map(String.init)

		if updatedTokens == expectedTokens {
			pendingTextTokens.removeAll()
			resolveWordyMoleMayhemAttempt(true, word: word)
			return
		}

		if expectedTokens.starts(with: updatedTokens) {
			pendingTextTokens = updatedTokens
			return
		}

		pendingTextTokens.removeAll()
		resolveWordyMoleMayhemAttempt(false, word: word)
	}

	private func resolveWordyMoleMayhemAttempt(_ hit: Bool, word: WordyMoleMayhemEntry) {
		if hit {
			handleWordyMoleMayhemHit(word)
			return
		}

		let lane = laneCount / 2
		GameAudioEngine.shared.playMiss(lane: lane)
		onMoleFeedback?(lane, .miss)
		onInputResetRequested?()

		if currentOptions.difficulty == .training || missRegisteredForMole {
			return
		}

		missRegisteredForMole = true
		missesThisRound += 1
		if let item = word.asBrailleItem() {
			recordMoleReconItem(item)
		}
		hitStreak = 0
		score = max(0, score - 2)
		onScoreUpdated?(score, hitStreak)
	}

	private func handleWordyMoleMayhemHit(_ word: WordyMoleMayhemEntry) {
		guard activeWordyMoleMayhemWord == word else { return }

		let lane = laneCount / 2
		let previousScore = score
		moleUpTimer?.cancel()
		moleUpTimer = nil
		hitsThisRound += 1
		lettersWhackedThisRound += word.length
		onInputResetRequested?()
		GameAudioEngine.shared.playHit(scoreBeforeHit: previousScore, lane: lane)
		onMoleFeedback?(lane, .hit)

		if currentOptions.difficulty == .training {
			trainingMolesCompleted += 1
			clearActiveMole()
			scheduleNextTrainingMole(extraDelayMs: trainingPostHitDelayMs)
			return
		}

		hitStreak += 1
		bestStreakThisRound = max(bestStreakThisRound, hitStreak)
		score += 10 + (word.length * 2)

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

		clearActiveMole()
		onScoreUpdated?(score, hitStreak)
		scheduleNextMole(extraDelayMs: 0)
	}

	private func pickNextWordyMoleMayhemWord() -> WordyMoleMayhemEntry? {
		guard !availableWordyMoleMayhemWords.isEmpty else { return nil }
		guard availableWordyMoleMayhemWords.count > 1 else {
			let word = availableWordyMoleMayhemWords[0]
			lastBlitzWord = word.text
			return word
		}

		var word = availableWordyMoleMayhemWords.randomElement()
		if word?.text == lastBlitzWord {
			word = availableWordyMoleMayhemWords.randomElement()
		}
		lastBlitzWord = word?.text
		return word
	}

	private func computeWordyMoleMayhemWindowMs(word: WordyMoleMayhemEntry, speechDurationMs: Int) -> Int {
		let perLetterMs: Int
		switch currentOptions.inputMode {
		case .qwerty:
			perLetterMs = 520
		case .perkins:
			perLetterMs = 720
		case .brailleText, .brailleDisplayInput:
			perLetterMs = 780
		case .oneHandedBrailleInput:
			perLetterMs = 1_000
		}

		let difficultyMultiplier = difficultyMultipliers[currentOptions.difficulty] ?? 1.0
		let entryTimeMs = Int(Double(perLetterMs * word.length) * difficultyMultiplier)
		let minimumMs = currentOptions.inputMode == .oneHandedBrailleInput ? 6_000 : 4_000
		let maximumMs = currentOptions.inputMode == .oneHandedBrailleInput ? 20_000 : 14_000
		return min(max(speechDurationMs + entryTimeMs + 600, minimumMs), maximumMs)
	}

	private func buildWordyMoleMayhemAnnounceText(for word: WordyMoleMayhemEntry) -> String {
		var parts = [word.text]
		if currentOptions.spellBlitzWords {
			parts.append(word.text.map(String.init).joined(separator: " "))
		}
		if currentOptions.difficulty == .training, currentOptions.speakBrailleDots {
			let patterns = word.contractedMasks
				.map(WordyMoleMayhemEntry.dotsForSpeech(for:))
			let dotPattern = BrailleItem.compactDotPatternText(for: patterns)
			if !dotPattern.isEmpty {
				parts.append(dotPattern)
			}
		}
		return parts.joined(separator: ", ")
	}

	private func handleHit() {
		guard let lane = activeLane else { return }

		if currentOptions.difficulty == .training {
			GameAudioEngine.shared.playHit(scoreBeforeHit: 0, lane: lane)
			onMoleFeedback?(lane, .hit)
			hitsThisRound += 1
			trainingMolesCompleted += 1
			onInputResetRequested?()
			missRegisteredForMole = true
			moleUpTimer?.cancel()
			moleUpTimer = nil
			clearActiveMole()
			scheduleNextTrainingMole(extraDelayMs: trainingPostHitDelayMs)
			return
		}

		let previousScore = score
		hitsThisRound += 1
		hitStreak += 1
		bestStreakThisRound = max(bestStreakThisRound, hitStreak)
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
		onMoleFeedback?(lane, .hit)
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
			onMoleFeedback?(lane, .miss)
		}
	}

	private func handleMiss() {
		guard let lane = activeLane else { return }

		missesThisRound += 1
		if let item = currentItem {
			recordMoleReconItem(item)
		}
		hitStreak = 0
		score = max(0, score - 2)

		GameAudioEngine.shared.playMiss(lane: lane)
		onMoleFeedback?(lane, .miss)
		onInputResetRequested?()
		onScoreUpdated?(score, hitStreak)
	}

	private func handlePerkinsAttempt(_ dotMask: Int?, currentItem: BrailleItem) {
		guard let dotMask else { return }

		let updatedSequence = pendingPerkinsMasks + [dotMask]
		let acceptedSequences = currentItem.acceptedPerkinsSequences.isEmpty
			? [currentItem.perkinsSequenceMasks]
			: currentItem.acceptedPerkinsSequences

		if currentItem.expectedPerkinsCellCount <= 1 {
			pendingPerkinsMasks.removeAll()
			resolveAttemptOutcome(acceptedSequences.contains(updatedSequence))
			return
		}

		if acceptedSequences.contains(where: { $0.starts(with: updatedSequence) }) {
			pendingPerkinsMasks = updatedSequence

			if acceptedSequences.contains(updatedSequence) {
				pendingPerkinsMasks.removeAll()
				resolveAttemptOutcome(true)
			}

			return
		}

		pendingPerkinsMasks.removeAll()
		resolveAttemptOutcome(false)
	}

	private func handleTextAttemptToken(_ token: String, currentItem: BrailleItem) {
		guard !token.isEmpty else { return }

		let updatedTokens = pendingTextTokens + [token]
		let sequences = currentItem.textInputTokenSequences

		if sequences.contains(updatedTokens) {
			pendingTextTokens.removeAll()
			resolveAttemptOutcome(true)
			return
		}

		if sequences.contains(where: { $0.starts(with: updatedTokens) }) {
			pendingTextTokens = updatedTokens
			return
		}

		pendingTextTokens.removeAll()
		resolveAttemptOutcome(false)
	}

	private func handleSubmittedText(_ input: String, currentItem: BrailleItem) {
		guard !input.isEmpty else { return }
		pendingTextTokens.removeAll()
		pendingPerkinsMasks.removeAll()
		resolveAttemptOutcome(matchesInput(input, item: currentItem))
	}

	private func resolveAttemptOutcome(_ hit: Bool) {
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

	private func buildAnnounceText(for item: BrailleItem) -> String {
		var text = item.announceText

		if item.id == "for", availableItems.contains(where: { $0.id == "4" }) {
			text = "F O R"
		}

		if item.id == "one", isItemAvailable("1") {
			text = "o n e"
		}

		if item.id == "be", isItemAvailable("b") {
			text = "B E"
		}

		if item.id == "you", isItemAvailable("u") {
			text = "Y O U"
		}

		if item.modeTags.contains("grade1Letters"), currentOptions.characterEcho, let nato = item.nato {
			text += ", \(nato)"
		}

		if currentOptions.difficulty == .training, currentOptions.speakBrailleDots {
			let cells = item.perkinsSequenceDots.isEmpty ? [item.dots] : item.perkinsSequenceDots
			let spokenCells = cells.compactMap { dotsPhrase(for: $0) }

			if !spokenCells.isEmpty {
				text += ", " + spokenCells.joined(separator: ", then ")
			}
		}

		return text
	}

	private func playGameplaySpeech(_ text: String) {
		SpeechEngine.shared.speak(text, interrupt: true)
	}

	private func isItemAvailable(_ id: String) -> Bool {
		availableItems.contains { $0.id == id }
	}

	private func scheduleFollowUp(afterTraining trainingMode: Bool) {
		if trainingMode {
			scheduleNextTrainingMole(extraDelayMs: 0)
		} else {
			scheduleNextMole(extraDelayMs: 0)
		}
	}

	private func pickRoundItems(modeId: String, pool: [BrailleItem], useSpatialMapping: Bool) -> [BrailleItem] {
		if isInvasionMode(modeId) {
			return []
		}

		if modeId == "customMoles" && currentOptions.customMolePlayMode == .individual {
			return Array(pool.prefix(laneCount))
		}

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
		if isInvasionMode(modeId) {
			return Array<BrailleItem?>(repeating: nil, count: laneCount)
		}

		if modeId == "customMoles" && currentOptions.customMolePlayMode == .individual {
			var lanes = Array<BrailleItem?>(repeating: nil, count: laneCount)
			for index in 0..<min(laneCount, items.count) {
				lanes[index] = items[index]
			}
			return lanes
		}

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
		let candidates = isInvasionMode
			? Array(0..<laneCount)
			: roundLaneItems.indices.filter { roundLaneItems[$0] != nil }
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
		invasionActiveItem = nil
		activeBlitzWord = nil
		activeBlitzLetterIndex = 0
		activeWordyMoleMayhemWord = nil
		activeMoleShownAtMs = 0
		pendingTextTokens.removeAll()
		pendingPerkinsMasks.removeAll()
		onActiveMoleChanged?(nil, nil)
		onActiveBlitzMolesChanged?([])
	}

	private func recordMoleReconItem(_ item: BrailleItem) {
		guard moleReconItemIDs.insert(item.id).inserted else { return }
		moleReconItems.append(item)
	}

	private func recordShownMoleReconItem(_ item: BrailleItem) {
		guard shownMoleReconItemIDs.insert(item.id).inserted else { return }
		shownMoleReconItems.append(item)
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

	private func computeMoleWindowMs(item: BrailleItem, baseUpTimeMs: Int, speechDurationMs: Int) -> Int {
		let reactionBufferMs = 380
		let minUpTimeMs = 550
		let maxUpTimeMs = currentOptions.inputMode == .oneHandedBrailleInput ? 3_600 : 2_700
		let effectiveSpeechDurationMs = max(300, speechDurationMs)
		let submissionBufferMs: Int
		let additionalCellBufferMs: Int
		switch currentOptions.inputMode {
		case .brailleDisplayInput:
			submissionBufferMs = 520
			additionalCellBufferMs = max(0, item.expectedPerkinsCellCount - 1) * 320
		case .oneHandedBrailleInput:
			let cellCount = min(max(item.expectedPerkinsCellCount, 1), 2)
			submissionBufferMs = 900 * cellCount
			additionalCellBufferMs = 0
		case .brailleText:
			submissionBufferMs = 320
			additionalCellBufferMs = max(0, item.expectedPerkinsCellCount - 1) * 320
		case .qwerty, .perkins:
			submissionBufferMs = 0
			additionalCellBufferMs = max(0, item.expectedPerkinsCellCount - 1) * 320
		}

		return min(
			max(
				baseUpTimeMs + effectiveSpeechDurationMs + reactionBufferMs + submissionBufferMs + additionalCellBufferMs,
				minUpTimeMs
			),
			maxUpTimeMs
		)
	}

	private func computeRoundEndGraceMs() -> Int {
		guard activeBlitzWord != nil || activeWordyMoleMayhemWord != nil,
			activeMoleShownAtMs > 0
		else { return 350 }
		let elapsedMs = TimeUtils.nowMs() - activeMoleShownAtMs
		let remainingMs = max(0, activeMoleUpTimeMs - elapsedMs)
		let maximumGraceMs = activeWordyMoleMayhemWord == nil ? 1_500 : 3_000
		return min(max(remainingMs, 350), maximumGraceMs)
	}

	private func scoreToTickets(_ score: Int) -> Int {
		if score >= 200 { return 20 }
		if score >= 150 { return 15 }
		if score >= 100 { return 10 }
		if score >= 50 { return 5 }
		return 0
	}

	private var isInvasionMode: Bool {
		isInvasionMode(currentOptions.modeId)
	}

	private var isGrade1BattleMode: Bool {
		BlitzWord.isGrade1BattleMode(currentOptions.modeId)
	}

	private var isWordyMoleMayhemMode: Bool {
		BlitzWord.isWordyMoleMayhemMode(currentOptions.modeId)
	}

	private var isWordMode: Bool {
		BlitzWord.isWordMode(currentOptions.modeId)
	}

	private func isInvasionMode(_ modeId: String) -> Bool {
		modeId == "grade1MoleInvasion"
			|| modeId == "grade2MoleInvasion"
			|| (modeId == "customMoles" && currentOptions.customMolePlayMode == .invasion)
	}

	private func items(for options: Options) -> [BrailleItem] {
		if options.modeId == "moleRecon" {
			return BrailleRegistry.customMoleItems(for: options.customMoleIDs, inputMode: options.inputMode)
		}

		if options.modeId != "customMoles" {
			return BrailleRegistry.getItems(for: options.modeId, inputMode: options.inputMode)
		}

		let selectedItems = BrailleRegistry.customMoleItems(for: options.customMoleIDs, inputMode: options.inputMode)
		if selectedItems.count >= laneCount {
			return selectedItems
		}

		return Array(BrailleRegistry.customMoleItems(for: options.inputMode).prefix(laneCount))
	}

	private func pickNextInvasionItem() -> BrailleItem? {
		guard !availableItems.isEmpty else { return nil }

		var candidates = availableItems

		if let lastItemID, sameItemRunCount >= 3 {
			let filtered = candidates.filter { $0.id != lastItemID }
			if !filtered.isEmpty {
				candidates = filtered
			}
		}

		let item = candidates.randomElement() ?? availableItems[0]

		if item.id == lastItemID {
			sameItemRunCount += 1
		} else {
			lastItemID = item.id
			sameItemRunCount = 1
		}

		return item
	}

	private func adjustedTickets(_ tickets: Int) -> Int {
		guard tickets > 0 else { return tickets }

		var adjusted = tickets

		if currentOptions.modeId == "grade2MoleInvasion" {
			adjusted = Int(ceil(Double(adjusted) * 1.5))
		}

		if currentOptions.modeId == "grade1MoleInvasion" {
			adjusted = Int(ceil(Double(adjusted) * 1.25))
		}

		switch currentOptions.modeId {
		case "grade1ThreeLetterBlitz":
			adjusted = Int(ceil(Double(adjusted) * 1.2))
		case "grade1FourLetterBlitz":
			adjusted = Int(ceil(Double(adjusted) * 1.3))
		case "grade1MoleBlitz":
			adjusted = Int(ceil(Double(adjusted) * 1.4))
		case WordyMoleMayhemCatalog.modeId:
			adjusted = Int(ceil(Double(adjusted) * 1.8))
		default:
			break
		}

		if currentOptions.inputMode == .oneHandedBrailleInput {
			adjusted *= 2
		}

		return adjusted
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

	private func isBufferedTextInputMode(_ inputMode: InputMode) -> Bool {
		inputMode.usesBufferedTextEntry
	}

	private func dotsPhrase(for dots: [Int]) -> String? {
		guard !dots.isEmpty else { return nil }

		if dots.count == 1, let first = dots.first {
			return "Dot \(first)"
		}

		return "Dots \(dots.map(String.init).joined(separator: " "))"
	}

	private func matchesInput(_ input: String, item: BrailleItem) -> Bool {
		guard !input.isEmpty else { return false }
		if item.acceptedTextInputs.contains(input) {
			return true
		}

		let compactedInput = input.filter { !$0.isWhitespace }
		guard compactedInput != input else { return false }
		return item.acceptedTextInputs.contains(String(compactedInput))
	}
}

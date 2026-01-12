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
}

import Foundation

@MainActor
final class GameViewModel: ObservableObject {

	let gameLoop: GameLoop

	@Published private(set) var isRunning: Bool = false
	@Published private(set) var score: Int = 0
	@Published private(set) var hitStreak: Int = 0
	@Published private(set) var activeLane: Int?
	@Published private(set) var activeTargetLabel: String = "Waiting to start"
	@Published private(set) var lastRoundResult: RoundResult?

	init(gameLoop: GameLoop = GameLoop()) {
		self.gameLoop = gameLoop

		self.gameLoop.onScoreUpdated = { [weak self] score, streak in
			guard let self else { return }
			Task { @MainActor in
				self.score = score
				self.hitStreak = streak
			}
		}

		self.gameLoop.onActiveMoleChanged = { [weak self] lane, item in
			guard let self else { return }
			Task { @MainActor in
				self.activeLane = lane
				self.activeTargetLabel = item?.id.uppercased() ?? (self.isRunning ? "Listen for the next mole" : "Waiting to start")
			}
		}

		self.gameLoop.onRoundEnded = { [weak self] result in
			guard let self else { return }
			Task { @MainActor in
				self.isRunning = false
				self.activeLane = nil
				self.activeTargetLabel = "Round finished"
				self.lastRoundResult = result
			}
		}
	}

	func startRound(
		modeId: String,
		durationSeconds: Int,
		inputMode: InputMode,
		difficulty: Difficulty,
		itemsForMode: [BrailleItem]
	) {
		lastRoundResult = nil
		activeLane = nil
		activeTargetLabel = "Get ready"
		isRunning = true

		gameLoop.startRound(
			modeId: modeId,
			durationSeconds: durationSeconds,
			inputMode: inputMode,
			difficulty: difficulty,
			itemsForMode: itemsForMode
		)
	}

	func stopRound() {
		gameLoop.stopRound()
		isRunning = false
		activeLane = nil
		activeTargetLabel = "Round stopped"
	}
}

import Foundation
import Combine

@MainActor
final class GameViewModel: ObservableObject {

	let gameLoop: GameLoop

	@Published private(set) var isRunning: Bool = false
	@Published private(set) var score: Int = 0
	@Published private(set) var hitStreak: Int = 0

	init(gameLoop: GameLoop = GameLoop()) {
		self.gameLoop = gameLoop

		// Keep UI in sync with GameLoop callbacks.
		self.gameLoop.onScoreUpdated = { [weak self] score, streak in
			guard let self else { return }
			Task { @MainActor in
				self.score = score
				self.hitStreak = streak
			}
		}

		self.gameLoop.onRoundEnded = { [weak self] _ in
			guard let self else { return }
			Task { @MainActor in
				self.isRunning = false
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
		// Flip published state FIRST so SwiftUI can render the pad immediately.
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
	}
}


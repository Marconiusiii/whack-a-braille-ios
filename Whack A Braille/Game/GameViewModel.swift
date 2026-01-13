import Foundation
import Combine
@MainActor
final class GameViewModel: ObservableObject {

	let gameLoop = GameLoop()

	@Published var score: Int = 0
	@Published var hitStreak: Int = 0
	@Published var isRunning: Bool = false

	init() {
		gameLoop.onScoreUpdated = { [weak self] score, streak in
			self?.score = score
			self?.hitStreak = streak
		}

		gameLoop.onRoundEnded = { [weak self] _ in
			self?.isRunning = false
		}
	}

	func startRound(
		modeId: String,
		durationSeconds: Int,
		inputMode: InputMode,
		items: [BrailleItem]
	) {
		isRunning = true

		gameLoop.startRound(
			modeId: modeId,
			durationSeconds: durationSeconds,
			inputMode: inputMode,
			itemsForMode: items
		)
	}

	func stopRound() {
		gameLoop.stopRound()
		isRunning = false
	}
}

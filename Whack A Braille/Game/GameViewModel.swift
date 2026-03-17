import Combine
import Foundation

@MainActor
final class GameViewModel: ObservableObject {

	enum Phase {
		case home
		case gameplay
		case roundResults
	}

	private enum StorageKey {
		static let totalTickets = "whackABraille.totalTickets"
	}

	let gameLoop: GameLoop

	@Published private(set) var phase: Phase = .home
	@Published private(set) var isRunning: Bool = false
	@Published private(set) var score: Int = 0
	@Published private(set) var hitStreak: Int = 0
	@Published private(set) var activeLane: Int?
	@Published private(set) var activeTargetLabel: String = "Waiting to start"
	@Published private(set) var lastRoundResult: RoundResult?
	@Published private(set) var totalAccruedTickets: Int
	@Published private(set) var homeNotice: String?

	var prizeShelfSummary: String {
		if totalAccruedTickets == 0 {
			return "Prize shelf is empty for now. Keep whacking to earn tickets."
		}

		return "You currently have \(totalAccruedTickets) tickets saved toward future prizes."
	}

	init(gameLoop: GameLoop? = nil) {
		let gameLoop = gameLoop ?? GameLoop()
		self.gameLoop = gameLoop
		self.totalAccruedTickets = UserDefaults.standard.integer(forKey: StorageKey.totalTickets)

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
				self.activeTargetLabel = item?.announceText ?? "Listen for the next mole"
			}
		}

		self.gameLoop.onRoundEnded = { [weak self] result in
			guard let self else { return }
			Task { @MainActor in
				self.isRunning = false
				self.activeLane = nil
				self.activeTargetLabel = result.canceled ? "Round stopped" : "Round finished"

				if result.canceled {
					self.phase = .home
					self.lastRoundResult = nil
					self.homeNotice = "Round stopped."
				} else {
					self.phase = .roundResults
					self.lastRoundResult = result
					self.totalAccruedTickets += result.totalTickets
					UserDefaults.standard.set(self.totalAccruedTickets, forKey: StorageKey.totalTickets)
				}
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
		homeNotice = nil
		score = 0
		hitStreak = 0
		activeLane = nil
		activeTargetLabel = "Get ready"
		isRunning = true
		phase = .gameplay

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
		phase = .home
		homeNotice = "Round stopped."
	}

	func cashInTickets() {
		phase = .home
		homeNotice = "Prize cash-in is coming soon. Your tickets are still saved."
	}
}

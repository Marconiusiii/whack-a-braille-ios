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
		static let prizeShelf = "whackABraille.prizeShelf"
	}

	let gameLoop: GameLoop

	@Published private(set) var phase: Phase = .home
	@Published private(set) var isRunning = false
	@Published private(set) var score = 0
	@Published private(set) var hitStreak = 0
	@Published private(set) var activeLane: Int?
	@Published private(set) var activeTargetLabel = "Waiting to start"
	@Published private(set) var lastRoundResult: RoundResult?
	@Published private(set) var lastRoundWasTraining = false
	@Published private(set) var totalAccruedTickets: Int
	@Published private(set) var prizeShelfItems: [String]
	@Published private(set) var homeNotice: String?

	init(gameLoop: GameLoop? = nil) {
		let gameLoop = gameLoop ?? GameLoop()
		self.gameLoop = gameLoop
		self.totalAccruedTickets = UserDefaults.standard.integer(forKey: StorageKey.totalTickets)
		self.prizeShelfItems = UserDefaults.standard.stringArray(forKey: StorageKey.prizeShelf) ?? []

		self.gameLoop.onScoreUpdated = { [weak self] score, streak in
			guard let self else { return }
			self.score = score
			self.hitStreak = streak
		}

		self.gameLoop.onActiveMoleChanged = { [weak self] lane, item in
			guard let self else { return }
			self.activeLane = lane
			self.activeTargetLabel = item?.announceText ?? "Listen for the next mole"
		}

		self.gameLoop.onRoundEnded = { [weak self] result in
			guard let self else { return }
			self.isRunning = false
			self.activeLane = nil
			self.activeTargetLabel = result.canceled ? "Round stopped" : "Round finished"

			if result.canceled {
				self.phase = .home
				self.lastRoundResult = nil
				self.lastRoundWasTraining = false
				self.homeNotice = "Round stopped."
			} else {
				self.lastRoundResult = result
				self.lastRoundWasTraining = result.isTraining
				self.phase = .roundResults

				if !result.isTraining {
					self.totalAccruedTickets += result.totalTickets
					UserDefaults.standard.set(self.totalAccruedTickets, forKey: StorageKey.totalTickets)
				}
			}
		}
	}

	func startRound(options: GameLoop.Options) {
		lastRoundResult = nil
		lastRoundWasTraining = options.difficulty == .training
		homeNotice = nil
		score = 0
		hitStreak = 0
		activeLane = nil
		activeTargetLabel = "Get ready"
		isRunning = true
		phase = .gameplay
	}

	func beginRound(options: GameLoop.Options) {
		gameLoop.startRound(options: options)
	}

	func stopRound() {
		gameLoop.stopRound()
	}

	func repeatCurrentTarget() {
		gameLoop.repeatCurrentTarget()
	}

	func cashInTickets() {
		phase = .home
		homeNotice = "Prize cash-in is coming soon. Your tickets are still saved."
	}

	func clearPrizeShelf() {
		prizeShelfItems = []
		UserDefaults.standard.removeObject(forKey: StorageKey.prizeShelf)
	}
}

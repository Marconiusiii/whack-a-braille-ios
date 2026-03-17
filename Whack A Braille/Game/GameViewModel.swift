import Combine
import Foundation

@MainActor
final class GameViewModel: ObservableObject {

	enum Phase {
		case home
		case gameplay
		case roundResults
		case cashOut
	}

	private enum StorageKey {
		static let totalTickets = "whackABraille.totalTickets"
		static let prizeShelf = "whackABraille.prizeShelf"
		static let prizeShelfEntries = "whackABraille.prizeShelfEntries"
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
	@Published private(set) var inputResetToken = 0
	@Published private(set) var cashOutPrizes: [Prize] = []
	@Published var selectedCashOutPrizeID: String?

	private var prizeShelfEntries: [PrizeShelfEntry]

	init(gameLoop: GameLoop? = nil) {
		let gameLoop = gameLoop ?? GameLoop()
		self.gameLoop = gameLoop
		self.totalAccruedTickets = UserDefaults.standard.integer(forKey: StorageKey.totalTickets)
		self.prizeShelfEntries = Self.loadPrizeShelfEntries()
		self.prizeShelfItems = Self.displayItems(from: self.prizeShelfEntries)

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

		self.gameLoop.onInputResetRequested = { [weak self] in
			self?.inputResetToken += 1
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
				GameAudioEngine.shared.playEndCue()
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
		inputResetToken += 1
		isRunning = true
		phase = .gameplay
	}

	func beginRound(options: GameLoop.Options) {
		gameLoop.startRound(options: options)
	}

	func stopRound() {
		gameLoop.stopRound()
	}

	func exitRoundToResults() {
		gameLoop.finishRoundEarly()
	}

	func repeatCurrentTarget() {
		gameLoop.repeatCurrentTarget()
	}

	func cashInTickets() {
		guard totalAccruedTickets >= 0 else { return }
		cashOutPrizes = Self.pickRandomPrizes(from: PrizeCatalog.eligible(for: totalAccruedTickets), count: 3)
		selectedCashOutPrizeID = nil
		phase = .cashOut
	}

	func selectCashOutPrize(_ prizeID: String) {
		selectedCashOutPrizeID = prizeID
	}

	func claimSelectedPrize() {
		guard let selectedCashOutPrizeID,
			let prize = cashOutPrizes.first(where: { $0.id == selectedCashOutPrizeID }) else { return }

		addPrizeToShelf(prize.label)
		totalAccruedTickets = 0
		UserDefaults.standard.set(totalAccruedTickets, forKey: StorageKey.totalTickets)
		cashOutPrizes = []
		self.selectedCashOutPrizeID = nil
		phase = .home
		homeNotice = "You claimed \(prize.label)."
	}

	func cancelCashOut() {
		phase = .roundResults
	}

	func clearPrizeShelf() {
		prizeShelfEntries = []
		prizeShelfItems = []
		UserDefaults.standard.removeObject(forKey: StorageKey.prizeShelfEntries)
		UserDefaults.standard.removeObject(forKey: StorageKey.prizeShelf)
		homeNotice = "Prize Shelf Cleared."
	}

	private func addPrizeToShelf(_ label: String) {
		if let index = prizeShelfEntries.firstIndex(where: { $0.label == label }) {
			prizeShelfEntries[index].quantity += 1
		} else {
			prizeShelfEntries.append(PrizeShelfEntry(label: label, quantity: 1))
		}

		savePrizeShelfEntries()
		prizeShelfItems = Self.displayItems(from: prizeShelfEntries)
	}

	private func savePrizeShelfEntries() {
		let encoder = JSONEncoder()
		if let data = try? encoder.encode(prizeShelfEntries) {
			UserDefaults.standard.set(data, forKey: StorageKey.prizeShelfEntries)
		}
	}

	private static func loadPrizeShelfEntries() -> [PrizeShelfEntry] {
		let decoder = JSONDecoder()

		if let data = UserDefaults.standard.data(forKey: StorageKey.prizeShelfEntries),
			let entries = try? decoder.decode([PrizeShelfEntry].self, from: data) {
			return entries
		}

		let legacyItems = UserDefaults.standard.stringArray(forKey: StorageKey.prizeShelf) ?? []
		var counts: [String: Int] = [:]
		for item in legacyItems {
			counts[item, default: 0] += 1
		}

		return counts.keys.sorted().map { key in
			PrizeShelfEntry(label: key, quantity: counts[key] ?? 1)
		}
	}

	private static func displayItems(from entries: [PrizeShelfEntry]) -> [String] {
		entries.map { entry in
			entry.quantity > 1 ? "\(entry.label) x\(entry.quantity)" : entry.label
		}
	}

	private static func pickRandomPrizes(from prizes: [Prize], count: Int) -> [Prize] {
		guard !prizes.isEmpty else { return [] }
		return Array(prizes.shuffled().prefix(max(0, count)))
	}
}

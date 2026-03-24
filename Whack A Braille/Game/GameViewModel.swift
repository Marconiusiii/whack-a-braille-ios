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
	@Published private(set) var prizeShelfCount: Int
	@Published private(set) var homeNotice: String?
	@Published private(set) var inputResetToken = 0
	@Published private(set) var howToPlayFocusToken = 0
	@Published private(set) var gameplayFocusToken = 0
	@Published private(set) var cashOutPrizes: [Prize] = []
	@Published private(set) var feedbackLane: Int?
	@Published private(set) var feedbackKind: GameLoop.FeedbackKind?

	private var prizeShelfEntries: [PrizeShelfEntry]
	private var feedbackResetTask: DispatchWorkItem?

	init(gameLoop: GameLoop? = nil) {
		let gameLoop = gameLoop ?? GameLoop()
		self.gameLoop = gameLoop
		self.totalAccruedTickets = UserDefaults.standard.integer(forKey: StorageKey.totalTickets)
		self.prizeShelfEntries = Self.loadPrizeShelfEntries()
		self.prizeShelfItems = Self.displayItems(from: self.prizeShelfEntries)
		self.prizeShelfCount = Self.totalPrizeCount(from: self.prizeShelfEntries)

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

		self.gameLoop.onMoleFeedback = { [weak self] lane, kind in
			guard let self else { return }
			self.feedbackResetTask?.cancel()
			self.feedbackLane = lane
			self.feedbackKind = kind

			let task = DispatchWorkItem { [weak self] in
				self?.feedbackLane = nil
				self?.feedbackKind = nil
			}
			self.feedbackResetTask = task
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: task)
		}

		self.gameLoop.onRoundEnded = { [weak self] result in
			guard let self else { return }
			self.isRunning = false
			self.activeLane = nil
			self.activeTargetLabel = result.canceled ? "Round stopped" : "Round finished"
			self.feedbackResetTask?.cancel()
			self.feedbackLane = nil
			self.feedbackKind = nil
			self.dismissGameplayInput()
			SpeechEngine.shared.cancel()
			GameAudioEngine.shared.stopRound()

			if result.canceled {
				self.lastRoundResult = nil
				self.lastRoundWasTraining = false
				self.homeNotice = "Round stopped."
				self.transitionPhase(to: .home)
			} else {
				self.lastRoundResult = result
				self.lastRoundWasTraining = result.isTraining

				if !result.isTraining {
					self.totalAccruedTickets += result.totalTickets
					UserDefaults.standard.set(self.totalAccruedTickets, forKey: StorageKey.totalTickets)
				}

				self.transitionPhase(to: .roundResults)
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
		feedbackResetTask?.cancel()
		feedbackLane = nil
		feedbackKind = nil
		inputResetToken += 1
		gameplayFocusToken += 1
		isRunning = true
		transitionPhase(to: .gameplay)
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

	func prepareCashOut() {
		guard totalAccruedTickets >= 0 else { return }
		cashOutPrizes = Self.pickRandomPrizes(from: PrizeCatalog.eligible(for: totalAccruedTickets), count: 3)
	}

	func claimPrize(_ prizeID: String) {
		guard let prize = cashOutPrizes.first(where: { $0.id == prizeID }) else { return }
		guard totalAccruedTickets >= prize.ticketCost else { return }

		GameAudioEngine.shared.playPrizeFanfare()
		addPrizeToShelf(prize.label)
		totalAccruedTickets -= prize.ticketCost
		UserDefaults.standard.set(totalAccruedTickets, forKey: StorageKey.totalTickets)
		cashOutPrizes = []
		homeNotice = nil
		transitionPhase(to: .home)
	}

	func cancelCashOut() {
		cashOutPrizes = []
	}

	func returnHomeFromCashOut() {
		cashOutPrizes = []
		homeNotice = nil
		transitionPhase(to: .home)
	}

	func returnHomeFromResults() {
		lastRoundResult = nil
		lastRoundWasTraining = false
		cashOutPrizes = []
		isRunning = false
		activeLane = nil
		feedbackResetTask?.cancel()
		feedbackLane = nil
		feedbackKind = nil
		dismissGameplayInput()
		transitionPhase(to: .home)
	}

	func saveTicketsAndReturnHome() {
		returnHomeFromResults()
	}

	func clearPrizeShelf() {
		prizeShelfEntries = []
		prizeShelfItems = []
		prizeShelfCount = 0
		UserDefaults.standard.removeObject(forKey: StorageKey.prizeShelfEntries)
		UserDefaults.standard.removeObject(forKey: StorageKey.prizeShelf)
		homeNotice = nil
	}

	func returnFocusToHowToPlay() {
		howToPlayFocusToken += 1
	}

	private func addPrizeToShelf(_ label: String) {
		if let index = prizeShelfEntries.firstIndex(where: { $0.label == label }) {
			prizeShelfEntries[index].quantity += 1
		} else {
			prizeShelfEntries.append(PrizeShelfEntry(label: label, quantity: 1))
		}

		savePrizeShelfEntries()
		prizeShelfItems = Self.displayItems(from: prizeShelfEntries)
		prizeShelfCount = Self.totalPrizeCount(from: prizeShelfEntries)
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
		entries.enumerated().map { index, entry in
			let baseLabel = entry.quantity > 1 ? "\(entry.label), x\(entry.quantity)" : entry.label
			return "\(index + 1). \(baseLabel)"
		}
	}

	private static func pickRandomPrizes(from prizes: [Prize], count: Int) -> [Prize] {
		guard !prizes.isEmpty else { return [] }
		return Array(prizes.shuffled().prefix(max(0, count)))
	}

	private static func totalPrizeCount(from entries: [PrizeShelfEntry]) -> Int {
		entries.reduce(0) { $0 + $1.quantity }
	}

	private func dismissGameplayInput() {
		inputResetToken += 1
		NotificationCenter.default.post(name: .dismissGameplayInput, object: nil)
	}

	private func transitionPhase(to phase: Phase) {
		DispatchQueue.main.async { [weak self] in
			self?.phase = phase
		}
	}
}

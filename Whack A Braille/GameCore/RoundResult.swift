struct RoundResult {
	let modeId: String
	let inputMode: InputMode
	let durationSeconds: Int
	let isTraining: Bool
	let trainingMolesCompleted: Int
	let isBlitzMode: Bool
	let lettersWhacked: Int

	let score: Int
	let hits: Int
	let misses: Int
	let escapes: Int
	let bestStreak: Int
	let streakBonusCount: Int
	let canceled: Bool
	let moleReconItems: [BrailleItem]
	let grudgeMatchItems: [BrailleItem]
	let usesAllShownMolesForRecon: Bool

	let baseTickets: Int
	let streakBonusTickets: Int
	let speedBonusTickets: Int

	var totalTickets: Int {
		baseTickets + streakBonusTickets + speedBonusTickets
	}
}

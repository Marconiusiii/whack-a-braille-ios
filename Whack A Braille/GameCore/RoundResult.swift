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

	var completedTargetLabel: String {
		BlitzWord.isWordMode(modeId) ? "Words completed" : "Hits"
	}

	var wordInputLabel: String? {
		if BlitzWord.isGrade1BattleMode(modeId) {
			return "Letters whacked"
		}
		if BlitzWord.isWordyMoleMayhemMode(modeId) {
			return "Letters typed"
		}
		return nil
	}

	var trainingCompletedLabel: String {
		BlitzWord.isWordMode(modeId) ? "Training words completed" : "Training moles completed"
	}

	var reconTargetNoun: String {
		BlitzWord.isWordMode(modeId) ? "words" : "moles"
	}
}

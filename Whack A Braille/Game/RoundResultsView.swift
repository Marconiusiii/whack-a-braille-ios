import SwiftUI

struct RoundResultsView: View {

	let result: RoundResult?
	let totalTickets: Int
	let keepWhacking: () -> Void
	let cashInTickets: () -> Void

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				if let result {
					Text(result.isTraining ? "Training Complete! Great Work!" : "Results")
						.font(.largeTitle.bold())
						.accessibilityAddTraits(.isHeader)

					VStack(alignment: .leading, spacing: 10) {
						if !result.isTraining {
							Text("Score: \(result.score)")
							Text("Tickets this round: \(result.totalTickets)")
							Text("Streak Bonus Tickets: \(result.streakBonusTickets)")
							Text("Speed Bonus Tickets: \(result.speedBonusTickets)")
							Text("Total tickets: \(totalTickets)")
						} else {
							Text("Training moles completed: \(result.trainingMolesCompleted)")
						}

						Text("Hits: \(result.hits)")
						Text("Misses: \(result.misses)")
						Text("Escapes: \(result.escapes)")
					}

					VStack(alignment: .leading, spacing: 12) {
						Button(result.isTraining ? "Keep Training!" : "Keep Whacking!", action: keepWhacking)
							.buttonStyle(.borderedProminent)

						if !result.isTraining {
							Button("Cash In Tickets and Pick a Prize", action: cashInTickets)
						}
					}
				}
			}
			.padding(20)
		}
	}
}

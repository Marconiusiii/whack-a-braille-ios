import SwiftUI

struct RoundResultsView: View {

	let result: RoundResult?
	let totalTickets: Int
	let keepWhacking: () -> Void
	let cashInTickets: () -> Void
	let onAppearAction: () -> Void

	@AccessibilityFocusState private var isHeadingFocused: Bool

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				if let result {
					Text(result.isTraining ? "Training Complete! Great Work!" : "Round Results")
						.font(.largeTitle.bold())
						.accessibilityAddTraits(.isHeader)
						.accessibilityFocused($isHeadingFocused)

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

						VStack(alignment: .leading, spacing: 4) {
							Text("Hits: \(result.hits)")
							Text("Misses: \(result.misses)")
							Text("Escapes: \(result.escapes)")
						}
						.accessibilityElement(children: .ignore)
						.accessibilityLabel("Hits \(result.hits), misses \(result.misses), escapes \(result.escapes)")
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
		.onAppear {
			onAppearAction()
			NotificationCenter.default.post(name: .dismissGameplayInput, object: nil)
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				isHeadingFocused = true
			}
		}
	}
}

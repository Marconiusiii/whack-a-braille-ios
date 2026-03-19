import SwiftUI

struct RoundResultsView: View {

	let result: RoundResult?
	let totalTickets: Int
	let keepWhacking: () -> Void
	let cashInTickets: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@AccessibilityFocusState private var isHeadingFocused: Bool

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				if let result {
					VStack(alignment: .leading, spacing: 12) {
						Text(result.isTraining ? "Training Complete! Great Work!" : "Round Results")
							.font(.system(size: 34, weight: .heavy, design: .rounded))
							.foregroundStyle(AppTheme.heading)
							.accessibilityAddTraits(.isHeader)
							.accessibilityFocused($isHeadingFocused)
					}
					.appCard()

					VStack(alignment: .leading, spacing: 10) {
						if !result.isTraining {
							Text("Score: \(result.score)")
								.summaryRowCard()
							Text("Tickets this round: \(result.totalTickets)")
								.summaryRowCard()
							Text("Streak Bonus Tickets: \(result.streakBonusTickets)")
								.summaryRowCard()
							Text("Speed Bonus Tickets: \(result.speedBonusTickets)")
								.summaryRowCard()
							Text("Total tickets: \(totalTickets)")
								.summaryRowCard()
						} else {
							Text("Training moles completed: \(result.trainingMolesCompleted)")
								.summaryRowCard()
						}

						VStack(alignment: .leading, spacing: 4) {
							Text("Hits: \(result.hits)")
							Text("Misses: \(result.misses)")
							Text("Escapes: \(result.escapes)")
						}
						.summaryRowCard()
						.accessibilityElement(children: .ignore)
						.accessibilityLabel("Hits \(result.hits), misses \(result.misses), escapes \(result.escapes)")
					}
					.foregroundStyle(primaryTextColor)
					.appCard()

					VStack(alignment: .leading, spacing: 12) {
						Button(result.isTraining ? "Keep Training!" : "Keep Whacking!", action: keepWhacking)
							.buttonStyle(PrimaryGameButton())

						if !result.isTraining {
							Button("Cash In Tickets and Pick a Prize", action: cashInTickets)
								.buttonStyle(SecondaryGameButton())
						}
					}
					.appCard()
				}
			}
			.padding(24)
		}
		.appBackground()
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				isHeadingFocused = true
			}
		}
	}

	private var primaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}
}

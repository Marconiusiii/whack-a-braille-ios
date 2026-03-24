import SwiftUI
import UIKit

struct RoundResultsView: View {

	let result: RoundResult?
	let totalTickets: Int
	let keepWhacking: () -> Void
	let cashInTickets: () -> Void
	let saveTicketsAndReturnHome: () -> Void
	let returnHome: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@AccessibilityFocusState private var isHeadingFocused: Bool

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				if let result {
					VStack(alignment: .leading, spacing: 12) {
						Text(result.isTraining ? "Training Complete! Great Work!" : "Round Results")
							.font(.system(.largeTitle, design: .rounded, weight: .heavy))
							.foregroundStyle(AppTheme.heading)
							.accessibilityAddTraits(.isHeader)
							.accessibilityFocused($isHeadingFocused)
					}
					.appCard()

					VStack(alignment: .leading, spacing: 10) {
						if !result.isTraining {
							Text("Score: \(result.score)")
								.summaryRowCard()
							VStack(alignment: .leading, spacing: 4) {
								Text("Tickets this round: \(result.totalTickets)")
								Text("Total tickets: \(totalTickets)")
							}
							.summaryRowCard()
							.accessibilityElement(children: .ignore)
							.accessibilityLabel("Tickets this round \(result.totalTickets), total tickets \(totalTickets)")
							VStack(alignment: .leading, spacing: 4) {
								Text("Streak Bonus Tickets: \(result.streakBonusTickets)")
								Text("Speed Bonus Tickets: \(result.speedBonusTickets)")
							}
							.summaryRowCard()
							.accessibilityElement(children: .ignore)
							.accessibilityLabel("Streak bonus tickets \(result.streakBonusTickets), speed bonus tickets \(result.speedBonusTickets)")
						} else {
							Text("Training moles completed: \(result.trainingMolesCompleted)")
								.summaryRowCard()
						}

						if !result.isTraining {
							VStack(alignment: .leading, spacing: 4) {
								Text("Hits: \(result.hits)")
								Text("Misses: \(result.misses)")
								Text("Escapes: \(result.escapes)")
							}
							.summaryRowCard()
							.accessibilityElement(children: .ignore)
							.accessibilityLabel("Hits \(result.hits), misses \(result.misses), escapes \(result.escapes)")
						}
					}
					.foregroundStyle(primaryTextColor)
					.appCard()

					VStack(alignment: .leading, spacing: 12) {
						Button(result.isTraining ? "Keep Training!" : "Keep Whacking!", action: keepWhacking)
							.buttonStyle(PrimaryGameButton())

						if result.isTraining {
							Button("Return Home", action: returnHome)
								.buttonStyle(SecondaryGameButton())
						}

						if !result.isTraining {
							Button("Save Tickets and Return Home", action: saveTicketsAndReturnHome)
								.buttonStyle(SecondaryGameButton())

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
			dismissTextInputSystem()
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
				dismissTextInputSystem()
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
				dismissTextInputSystem()
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				isHeadingFocused = true
			}
		}
	}

	private func dismissTextInputSystem() {
		NotificationCenter.default.post(name: .dismissGameplayInput, object: nil)
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
		for scene in UIApplication.shared.connectedScenes {
			guard let windowScene = scene as? UIWindowScene else { continue }
			for window in windowScene.windows {
				window.endEditing(true)
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

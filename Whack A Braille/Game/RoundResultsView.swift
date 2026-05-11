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
		VStack(alignment: .leading, spacing: 0) {
			if let result {
				VStack(alignment: .leading, spacing: 12) {
					Text(result.isTraining ? "Training Complete! Great Work!" : "Round Results")
						.font(.system(.largeTitle, design: .rounded, weight: .heavy))
						.foregroundStyle(AppTheme.heading)
						.accessibilityAddTraits(.isHeader)
						.accessibilityFocused($isHeadingFocused)
				}
				.appCard()
				.accessibilityTouchRegion(minHeight: 0, topPadding: 24, bottomPadding: 10, horizontalPadding: 24, alignment: .leading)

				VStack(alignment: .leading, spacing: 0) {
					if !result.isTraining {
						Text("Score: \(result.score)")
							.summaryRowCard()
							.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						VStack(alignment: .leading, spacing: 4) {
							Text("Tickets this round: \(result.totalTickets)")
							Text("Total tickets: \(totalTickets)")
						}
						.summaryRowCard()
						.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						.accessibilityElement(children: .ignore)
						.accessibilityLabel("Tickets this round \(result.totalTickets), total tickets \(totalTickets)")
						VStack(alignment: .leading, spacing: 4) {
							Text("Streak Bonus Tickets: \(result.streakBonusTickets)")
							Text("Speed Bonus Tickets: \(result.speedBonusTickets)")
						}
						.summaryRowCard()
						.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						.accessibilityElement(children: .ignore)
						.accessibilityLabel("Streak bonus tickets \(result.streakBonusTickets), speed bonus tickets \(result.speedBonusTickets)")
					} else {
						Text("Training moles completed: \(result.trainingMolesCompleted)")
							.summaryRowCard()
							.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
					}

					if !result.isTraining {
						VStack(alignment: .leading, spacing: 4) {
							Text("Hits: \(result.hits)")
							Text("Misses: \(result.misses)")
							Text("Escapes: \(result.escapes)")
						}
						.summaryRowCard()
						.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						.accessibilityElement(children: .ignore)
						.accessibilityLabel("Hits \(result.hits), misses \(result.misses), escapes \(result.escapes)")
					}
				}
				.foregroundStyle(primaryTextColor)
				.appCard()
				.accessibilityTouchRegion(minHeight: 0, topPadding: 10, bottomPadding: 0, horizontalPadding: 24, alignment: .leading)

				Button(result.isTraining ? "Keep Training!" : "Keep Whacking!", action: keepWhacking)
					.buttonStyle(FullRegionPrimaryGameButton(visibleMinHeight: 72, horizontalInset: 24, verticalInset: 20))
					.frame(maxWidth: .infinity, maxHeight: .infinity)

				if result.isTraining {
					Button("Return Home", action: returnHome)
						.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 24, verticalInset: 20))
						.frame(maxWidth: .infinity, minHeight: 140)
				} else {
					HStack(spacing: 0) {
						Button("Save Tickets", action: saveTicketsAndReturnHome)
							.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 16, verticalInset: 20))
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.accessibilityLabel("Save Tickets and Return Home")

						Button("Cash In", action: cashInTickets)
							.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 16, verticalInset: 20))
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.accessibilityLabel("Cash In Tickets and Pick a Prize")
					}
					.frame(maxWidth: .infinity, minHeight: 150)
				}
			}
		}
		.appBackground()
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

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
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@AccessibilityFocusState private var isHeadingFocused: Bool
	@State private var isResultsContentAccessible = false

	var body: some View {
		Group {
			if usesAccessibilityLayout {
				ScrollView {
					resultContent(accessibilityLayout: true)
						.padding(.bottom, 24)
				}
			} else {
				resultContent(accessibilityLayout: false)
			}
		}
		.appBackground()
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.onAppear {
				isResultsContentAccessible = false
				isHeadingFocused = false
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					DispatchQueue.main.async {
						UIAccessibility.post(notification: .screenChanged, argument: nil)
					}
				}
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					isHeadingFocused = true
				}
				DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
					isResultsContentAccessible = true
				}
			}
	}

	private var usesAccessibilityLayout: Bool {
		dynamicTypeSize.isAccessibilitySize
	}

	private var headingText: String {
		result?.isTraining == true ? "Training Complete! Great Work!" : "Round Results"
	}

	private func resultContent(accessibilityLayout: Bool) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			if let result {
				VStack(alignment: .leading, spacing: 12) {
					Text(headingText)
						.font(.system(.largeTitle, design: .rounded, weight: .heavy))
						.foregroundStyle(AppTheme.heading)
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityAddTraits(.isHeader)
						.accessibilityFocused($isHeadingFocused)
				}
				.appCard()
				.accessibilityTouchRegion(minHeight: 0, topPadding: 24, bottomPadding: 10, horizontalPadding: 24, alignment: .leading)

				VStack(alignment: .leading, spacing: 0) {
					if !result.isTraining {
						Text("Score: \(result.score)")
							.fixedSize(horizontal: false, vertical: true)
							.summaryRowCard()
							.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						VStack(alignment: .leading, spacing: 4) {
							Text("Tickets this round: \(result.totalTickets)")
								.fixedSize(horizontal: false, vertical: true)
							Text("Total tickets: \(totalTickets)")
								.fixedSize(horizontal: false, vertical: true)
						}
						.summaryRowCard()
						.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						.accessibilityElement(children: .ignore)
						.accessibilityLabel("Tickets this round \(result.totalTickets), total tickets \(totalTickets)")
						VStack(alignment: .leading, spacing: 4) {
							Text("Streak Bonus Tickets: \(result.streakBonusTickets)")
								.fixedSize(horizontal: false, vertical: true)
							Text("Speed Bonus Tickets: \(result.speedBonusTickets)")
								.fixedSize(horizontal: false, vertical: true)
						}
						.summaryRowCard()
						.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						.accessibilityElement(children: .ignore)
						.accessibilityLabel("Streak bonus tickets \(result.streakBonusTickets), speed bonus tickets \(result.speedBonusTickets)")
					} else {
						Text("Training moles completed: \(result.trainingMolesCompleted)")
							.fixedSize(horizontal: false, vertical: true)
							.summaryRowCard()
							.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
					}

					if !result.isTraining {
						VStack(alignment: .leading, spacing: 4) {
							Text("Hits: \(result.hits)")
								.fixedSize(horizontal: false, vertical: true)
							Text("Misses: \(result.misses)")
								.fixedSize(horizontal: false, vertical: true)
							Text("Escapes: \(result.escapes)")
								.fixedSize(horizontal: false, vertical: true)
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
				.accessibilityHidden(!isResultsContentAccessible)

				Button(result.isTraining ? "Keep Training!" : "Keep Whacking!", action: keepWhacking)
					.buttonStyle(FullRegionPrimaryGameButton(visibleMinHeight: 72, horizontalInset: 24, verticalInset: 20))
					.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 120 : nil, maxHeight: accessibilityLayout ? nil : .infinity)
					.accessibilityHidden(!isResultsContentAccessible)

				if result.isTraining {
					Button("Return Home", action: returnHome)
						.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 24, verticalInset: 20))
						.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 104 : 140, maxHeight: accessibilityLayout ? nil : .infinity)
						.accessibilityHidden(!isResultsContentAccessible)
				} else {
					if accessibilityLayout {
						VStack(spacing: 0) {
							bottomActionButtons(maxHeight: nil, minHeight: 104)
						}
						.accessibilityHidden(!isResultsContentAccessible)
					} else {
						HStack(spacing: 0) {
							bottomActionButtons(maxHeight: .infinity, minHeight: nil)
						}
						.frame(maxWidth: .infinity, minHeight: 150)
						.accessibilityHidden(!isResultsContentAccessible)
					}
				}
			}
		}
	}

	@ViewBuilder
	private func bottomActionButtons(maxHeight: CGFloat?, minHeight: CGFloat?) -> some View {
		Button("Save Tickets", action: saveTicketsAndReturnHome)
			.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 16, verticalInset: 20))
			.frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight)
			.accessibilityLabel("Save Tickets and Return Home")

		Button("Cash In", action: cashInTickets)
			.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 16, verticalInset: 20))
			.frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight)
			.accessibilityLabel("Cash In Tickets and Pick a Prize")
	}

	private var primaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}
}

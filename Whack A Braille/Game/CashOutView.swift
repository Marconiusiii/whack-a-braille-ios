import SwiftUI

struct CashOutView: View {

	let totalTickets: Int
	let prizes: [Prize]
	let showKeepWhacking: Bool
	let claimPrize: (String) -> Void
	let keepWhacking: () -> Void
	let returnHome: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@AccessibilityFocusState private var isHeadingFocused: Bool

	var body: some View {
		Group {
			if usesAccessibilityLayout {
				ScrollView {
					cashOutContent(accessibilityLayout: true)
						.padding(.bottom, 24)
				}
			} else {
				cashOutContent(accessibilityLayout: false)
			}
		}
		.appBackground()
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				isHeadingFocused = true
			}
		}
	}

	private var usesAccessibilityLayout: Bool {
		dynamicTypeSize.isAccessibilitySize
	}

	private func cashOutContent(accessibilityLayout: Bool) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			VStack(alignment: .leading, spacing: 0) {
					Text("Pick a Prize!")
						.font(.system(.largeTitle, design: .rounded, weight: .heavy))
						.foregroundStyle(AppTheme.heading)
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityTouchRegion(minHeight: 0, topPadding: 20, bottomPadding: 6, horizontalPadding: 20, alignment: .leading)
						.accessibilityAddTraits(.isHeader)
						.accessibilityFocused($isHeadingFocused)

					Text("Your tickets are ready to trade. Pick the prize that suits your fancy, or keep whacking and save up for a bigger score.")
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityTouchRegion(minHeight: 0, verticalPadding: 6, horizontalPadding: 20, alignment: .leading)

					Text("Tickets ready: \(totalTickets)")
						.fixedSize(horizontal: false, vertical: true)
						.summaryRowCard()
						.accessibilityTouchRegion(minHeight: 0, topPadding: 6, bottomPadding: 20, horizontalPadding: 20, alignment: .leading)
						.foregroundStyle(colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText)
			}
			.appActionCard()

			VStack(alignment: .leading, spacing: 0) {
				if prizes.isEmpty || totalTickets <= 0 {
					Text("Your ticket jar is emptier than a mole hill after a whack storm. Go whack some moles and come back for something shiny!")
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityTouchRegion(minHeight: 96, topPadding: 20, bottomPadding: 6, horizontalPadding: 20, alignment: .leading)

					if showKeepWhacking {
						Button("Keep Whacking!", action: keepWhacking)
							.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 20, verticalInset: 6))
							.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 96 : 76)
					}
				} else {
					ForEach(Array(prizes.enumerated()), id: \.element.id) { index, prize in
						Button(prize.label) {
							claimPrize(prize.id)
						}
						.buttonStyle(FullRegionPrimaryGameButton(horizontalInset: 20, verticalInset: 6))
						.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 112 : (index == 0 ? 96 : 76))
						.accessibilityValue("\(index + 1) of \(prizes.count), \(prize.ticketCost) " + (prize.ticketCost == 1 ? "ticket" : "tickets"))
						.accessibilityHint("Double-tap to claim.")
					}

					if showKeepWhacking {
						Button("Keep Whacking!", action: keepWhacking)
							.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 20, verticalInset: 6))
							.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 96 : 76)
					}
				}

				Button("Return Home", action: returnHome)
					.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 20, verticalInset: 20))
					.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 104 : nil, maxHeight: accessibilityLayout ? nil : .infinity)
			}
			.appActionCard()
			.frame(maxWidth: .infinity, maxHeight: accessibilityLayout ? nil : .infinity, alignment: .top)
		}
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}
}

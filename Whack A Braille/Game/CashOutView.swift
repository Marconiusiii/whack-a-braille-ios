import SwiftUI

struct CashOutView: View {

	let totalTickets: Int
	let prizes: [Prize]
	let claimPrize: (String) -> Void
	let keepWhacking: () -> Void
	let returnHome: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@AccessibilityFocusState private var isHeadingFocused: Bool

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				VStack(alignment: .leading, spacing: 12) {
					Text("Pick a Prize!")
						.font(.system(.largeTitle, design: .rounded, weight: .heavy))
						.foregroundStyle(AppTheme.heading)
						.accessibilityAddTraits(.isHeader)
						.accessibilityFocused($isHeadingFocused)

					Text("Your tickets are ready to trade. Pick the prize that suits your fancy, or keep whacking and save up for a bigger score.")
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)

					Text("Tickets ready: \(totalTickets)")
						.summaryRowCard()
						.foregroundStyle(colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText)
				}
				.appCard()

				VStack(alignment: .leading, spacing: 12) {
					ForEach(Array(prizes.enumerated()), id: \.element.id) { index, prize in
						Button(prize.label) {
							claimPrize(prize.id)
						}
						.buttonStyle(PrimaryGameButton())
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityValue("\(index + 1) of \(prizes.count), \(prize.ticketCost) " + (prize.ticketCost == 1 ? "ticket" : "tickets"))
						.accessibilityHint("Double-tap to claim.")
					}

					Button("Keep Whacking!", action: keepWhacking)
						.buttonStyle(SecondaryGameButton())

					Button("Return Home", action: returnHome)
						.buttonStyle(SecondaryGameButton())
				}
				.appCard()
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

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}
}

import SwiftUI

struct CashOutView: View {

	let totalTickets: Int
	let prizes: [Prize]
	let claimPrize: (String) -> Void
	let keepWhacking: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@AccessibilityFocusState private var isHeadingFocused: Bool

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				VStack(alignment: .leading, spacing: 12) {
					Text("Pick a Prize!")
						.font(.system(size: 34, weight: .heavy, design: .rounded))
						.foregroundStyle(AppTheme.heading)
						.accessibilityAddTraits(.isHeader)
						.accessibilityFocused($isHeadingFocused)

					Text("Your tickets are ready to trade. Pick the prize that catches your ear, or keep whacking and save up for a bigger score.")
						.foregroundStyle(secondaryTextColor)
				}
				.appCard()

				VStack(alignment: .leading, spacing: 12) {
					ForEach(Array(prizes.enumerated()), id: \.element.id) { index, prize in
						Button(prize.label) {
							claimPrize(prize.id)
						}
						.buttonStyle(PrimaryGameButton())
						.accessibilityValue("\(index + 1) of \(prizes.count)")
						.accessibilityHint("Double-tap to claim.")
					}

					Button("Keep Whacking!", action: keepWhacking)
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

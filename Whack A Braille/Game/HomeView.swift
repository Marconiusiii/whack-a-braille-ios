import SwiftUI

struct HomeView: View {

	let prizeShelfItems: [String]
	let homeNotice: String?
	let openSettings: () -> Void
	let startGame: () -> Void
	let clearPrizeShelf: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@State private var isPrizeShelfExpanded = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				VStack(alignment: .leading, spacing: 12) {
					Text("Whack A Braille")
						.font(.system(size: 38, weight: .heavy, design: .rounded))
						.foregroundStyle(AppTheme.title)
						.accessibilityAddTraits(.isHeader)

					Text("Listen sharp, type fast, and send those braille moles scampering before they duck away. Rack up tickets with Braille Screen Input, a keyboard, or your braille display, then cash in for prizes.")
						.foregroundStyle(secondaryTextColor)

					if let homeNotice {
						Text(homeNotice)
							.foregroundStyle(AppTheme.heading)
					}
				}
				.appCard()

				VStack(alignment: .leading, spacing: 12) {
					Button("Game Settings", action: openSettings)
						.buttonStyle(SecondaryGameButton())

					Button("Start Whacking", action: startGame)
						.buttonStyle(PrimaryGameButton())
				}
				.appCard()

				DisclosureGroup("Prize Shelf", isExpanded: $isPrizeShelfExpanded) {
					VStack(alignment: .leading, spacing: 12) {
						if prizeShelfItems.isEmpty {
							Text("Your shelf is empty. Go bonk some moles and win something shiny!")
								.foregroundStyle(secondaryTextColor)
						} else {
							ForEach(prizeShelfItems, id: \.self) { item in
								Text(item)
									.foregroundStyle(primaryTextColor)
							}
						}

						Button("Clear Prize Shelf", action: clearPrizeShelf)
							.buttonStyle(SecondaryGameButton())
					}
					.padding(.top, 8)
				}
				.tint(AppTheme.heading)
				.foregroundStyle(AppTheme.heading)
				.appCard()
			}
			.padding(24)
		}
		.appBackground()
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}

	private var primaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}
}

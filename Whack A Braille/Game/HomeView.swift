import SwiftUI

struct HomeView: View {

	let totalTickets: Int
	let prizeShelfSummary: String
	let homeNotice: String?
	let openSettings: () -> Void
	let startGame: () -> Void

	@AccessibilityFocusState private var focusedHeading: Bool

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {
					VStack(alignment: .leading, spacing: 12) {
						Text("Whack A Braille")
							.font(.largeTitle.bold())
							.accessibilityAddTraits(.isHeader)
							.accessibilityFocused($focusedHeading)

						Text("Listen for the target, then whack it before it disappears using Braille Screen Input, an external keyboard, or a connected braille display.")
					}

					if let homeNotice {
						Text(homeNotice)
							accessibilityAddTraits(.isStaticText)
					}

					VStack(alignment: .leading, spacing: 12) {
						Button("Game Settings", action: openSettings)
						Button("Start Whacking", action: startGame)
							.buttonStyle(.borderedProminent)
					}

					VStack(alignment: .leading, spacing: 8) {
						Text("Prize Shelf")
							.font(.title2.bold())
							.accessibilityAddTraits(.isHeader)
						Text("Saved tickets: \(totalTickets)")
						Text(prizeShelfSummary)
					}
				}
				.padding(20)
			}
			.navigationBarTitleDisplayMode(.inline)
		}
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
				focusedHeading = true
			}
		}
	}
}

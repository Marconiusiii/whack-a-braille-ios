import SwiftUI

struct HomeView: View {

	let totalTickets: Int
	let prizeShelfSummary: String
	let homeNotice: String?
	let openSettings: () -> Void
	let startGame: () -> Void

	@AccessibilityFocusState private var focusedElement: FocusTarget?

	private enum FocusTarget: Hashable {
		case heading
		case startButton
	}

	var body: some View {
		NavigationStack {
			List {
				Section {
					Text("Whack A Braille")
						.font(.largeTitle.bold())
						.accessibilityAddTraits(.isHeader)
						.accessibilityFocused($focusedElement, equals: .heading)

					Text("Listen for the braille character, number, or contraction, then whack it before it disappears. Use Braille Screen Input, an external keyboard, or a connected braille display.")
				}

				if let homeNotice {
					Section("Status") {
						Text(homeNotice)
					}
				}

				Section("Start") {
					Button("Game Settings", action: openSettings)

					Button("Start Whacking", action: startGame)
						.buttonStyle(.borderedProminent)
						.accessibilityFocused($focusedElement, equals: .startButton)
				}

				Section("Prize Shelf") {
					Text("Saved tickets: \(totalTickets)")
					Text(prizeShelfSummary)
				}
			}
			.navigationBarTitleDisplayMode(.inline)
		}
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
				focusedElement = .startButton
			}
		}
	}
}

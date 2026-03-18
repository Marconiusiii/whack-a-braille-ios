import SwiftUI

struct CashOutView: View {

	let totalTickets: Int
	let prizes: [Prize]
	let claimPrize: (String) -> Void
	let keepWhacking: () -> Void

	@AccessibilityFocusState private var isHeadingFocused: Bool

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				Text("Pick a Prize!")
					.font(.largeTitle.bold())
					.accessibilityAddTraits(.isHeader)
					.accessibilityFocused($isHeadingFocused)

				VStack(alignment: .leading, spacing: 10) {
					Text("You have \(totalTickets) tickets.")
					Text("Choose one of the wonderful prizes, or keep playing to win more tickets.")
				}

				VStack(alignment: .leading, spacing: 12) {
					Text("Available prizes")
						.font(.headline)
						.accessibilityHidden(true)

					ForEach(prizes) { prize in
						Button("Claim \(prize.label)") {
							claimPrize(prize.id)
						}
						.buttonStyle(.borderedProminent)
					}

					Button("Keep Whacking!", action: keepWhacking)
						.buttonStyle(.bordered)
				}
			}
			.padding(20)
		}
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				isHeadingFocused = true
			}
		}
	}
}

import SwiftUI

struct CashOutView: View {

	let totalTickets: Int
	let prizes: [Prize]
	let claimPrize: (String?) -> Void
	let keepWhacking: () -> Void

	@State private var selectedPrizeID: String?

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				Text("Pick a Prize!")
					.font(.largeTitle.bold())
					.accessibilityAddTraits(.isHeader)

				VStack(alignment: .leading, spacing: 10) {
					Text("You have \(totalTickets) tickets.")
					Text("Choose one of the wonderful prizes, or keep playing to win more tickets.")
				}

				VStack(alignment: .leading, spacing: 12) {
					Text("Available prizes")
						.font(.headline)

					ForEach(prizes) { prize in
						Button {
							selectedPrizeID = prize.id
						} label: {
							HStack(alignment: .top, spacing: 12) {
								Image(systemName: selectedPrizeID == prize.id ? "largecircle.fill.circle" : "circle")
								Text(prize.label)
									frame(maxWidth: .infinity, alignment: .leading)
							}
						}
						.buttonStyle(.plain)
						.accessibilityLabel(prize.label)
						.accessibilityValue(selectedPrizeID == prize.id ? "Selected" : "Not selected")
					}
				}

				VStack(alignment: .leading, spacing: 12) {
					Button("Claim Selected Prize") {
						claimPrize(selectedPrizeID)
					}
						.buttonStyle(.borderedProminent)
						.disabled(selectedPrizeID == nil)

					Button("Keep Whacking!", action: keepWhacking)
						.buttonStyle(.bordered)
				}
			}
			.padding(20)
		}
		.onAppear {
			if selectedPrizeID == nil {
				selectedPrizeID = prizes.first?.id
			}
		}
	}
}

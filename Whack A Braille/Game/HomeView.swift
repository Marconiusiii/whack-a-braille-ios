import SwiftUI

struct HomeView: View {

	let prizeShelfItems: [String]
	let homeNotice: String?
	let openSettings: () -> Void
	let startGame: () -> Void
	let clearPrizeShelf: () -> Void

	@State private var isPrizeShelfExpanded = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				Text("Whack A Braille")
					.font(.largeTitle.bold())
					.accessibilityAddTraits(.isHeader)

				Text("Listen for the target, then whack it before it disappears using Braille Screen Input, an external keyboard, or a connected braille display.")

				if let homeNotice {
					Text(homeNotice)
				}
 
				Button("Game Settings", action: openSettings)
					.buttonStyle(.bordered)

				Button("Start Whacking", action: startGame)
					.buttonStyle(.borderedProminent)

				DisclosureGroup("Prize Shelf", isExpanded: $isPrizeShelfExpanded) {
					VStack(alignment: .leading, spacing: 12) {
						if prizeShelfItems.isEmpty {
							Text("You haven't won any prizes yet!")
						} else {
							ForEach(prizeShelfItems, id: \.self) { item in
								Text(item)
							}
						}

						Button("Clear Prize Shelf", action: clearPrizeShelf)
							.buttonStyle(.bordered)
					}
					.padding(.top, 8)
				}
			}
			.frame(maxWidth: .infinity, alignment: .topLeading)
			.padding(24)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
}

import SwiftUI

struct HomeView: View {

	let prizeShelfItems: [String]
	let homeNotice: String?
	let openSettings: () -> Void
	let startGame: () -> Void
	let clearPrizeShelf: () -> Void

	@State private var isPrizeShelfExpanded = false

	var body: some View {
		List {
			Section {
				Text("Whack A Braille")
					.font(.largeTitle.bold())
					.accessibilityAddTraits(.isHeader)

				Text("Listen for the target, then whack it before it disappears using Braille Screen Input, an external keyboard, or a connected braille display.")

				if let homeNotice {
					Text(homeNotice)
				}
			}

			Section {
				Button("Game Settings", action: openSettings)
					.buttonStyle(.bordered)

				Button("Start Whacking", action: startGame)
					.buttonStyle(.borderedProminent)
			}

			Section {
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
		}
		.listStyle(.insetGrouped)
	}
}

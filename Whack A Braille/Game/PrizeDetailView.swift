import SwiftUI

struct PrizeDetailView: View {

	let item: GameViewModel.PrizeShelfDisplayItem
	let dismissToShelf: () -> Void

	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 0) {
					VStack(alignment: .leading, spacing: 12) {
						Text(item.label)
							.font(.system(.largeTitle, design: .rounded, weight: .heavy))
							.foregroundStyle(AppTheme.title)
							.accessibilityAddTraits(.isHeader)

						Text(dateClaimedText)
							.foregroundStyle(secondaryTextColor)

						Text(tierAndTicketText)
							.foregroundStyle(AppTheme.heading)

						Text(item.flavorText)
							.foregroundStyle(secondaryTextColor)
							.fixedSize(horizontal: false, vertical: true)

						if item.quantity >= 2 {
							Text("Total Owned: \(item.quantity)")
								.foregroundStyle(AppTheme.heading)
						}
					}
					.appCard()
					.accessibilityTouchRegion(minHeight: 0, verticalPadding: 10, alignment: .leading)

					VStack(alignment: .leading, spacing: 0) {
						Button("Back to Shelf", action: dismissToShelf)
							.buttonStyle(SecondaryGameButton())
							.accessibilityTouchRegion(minHeight: 76, topPadding: 20, bottomPadding: 20, horizontalPadding: 20)
					}
					.appActionCard()
					.accessibilityTouchRegion(minHeight: 0, verticalPadding: 10, alignment: .leading)
				}
				.padding(24)
			}
			.appBackground()
			.navigationBarTitleDisplayMode(.inline)
		}
		.accessibilityAction(.escape) {
			dismissToShelf()
		}
	}

	private var dateClaimedText: String {
		"Date Claimed: \(formattedClaimDate)"
	}

	private var tierAndTicketText: String {
		"\(item.tier.detailLabel), \(item.ticketCost) \(item.ticketCost == 1 ? "ticket" : "tickets")"
	}

	private var formattedClaimDate: String {
		guard let latestClaimedAt = item.latestClaimedAt else {
			return "Before claim dates were tracked"
		}

		return latestClaimedAt.formatted(date: .abbreviated, time: .omitted)
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}
}

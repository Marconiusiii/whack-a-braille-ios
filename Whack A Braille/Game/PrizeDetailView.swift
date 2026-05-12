import SwiftUI

struct PrizeDetailView: View {

	let item: GameViewModel.PrizeShelfDisplayItem
	let dismissToShelf: () -> Void

	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading, spacing: 0) {
				VStack(alignment: .leading, spacing: 0) {
					Text(item.label)
						.font(.system(.largeTitle, design: .rounded, weight: .heavy))
						.foregroundStyle(AppTheme.title)
						.accessibilityTouchRegion(minHeight: 0, topPadding: 20, bottomPadding: 8, horizontalPadding: 20, alignment: .leading)
						.accessibilityAddTraits(.isHeader)

					Text(dateClaimedText)
						.foregroundStyle(secondaryTextColor)
						.accessibilityTouchRegion(minHeight: 0, verticalPadding: 8, horizontalPadding: 20, alignment: .leading)

					Text(tierAndTicketText)
						.foregroundStyle(AppTheme.heading)
						.accessibilityTouchRegion(minHeight: 0, verticalPadding: 8, horizontalPadding: 20, alignment: .leading)

					Text(item.flavorText)
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityTouchRegion(minHeight: 0, verticalPadding: 8, horizontalPadding: 20, alignment: .leading)

					if item.quantity >= 2 {
						Text("Total Owned: \(item.quantity)")
							.foregroundStyle(AppTheme.heading)
							.accessibilityTouchRegion(minHeight: 0, topPadding: 8, bottomPadding: 20, horizontalPadding: 20, alignment: .leading)
					}
				}
				.appActionCard()

				Button("Back to Shelf", action: dismissToShelf)
					.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 20, verticalInset: 20))
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.appActionCard()
			}
			.padding(24)
			.appBackground()
			.navigationBarTitleDisplayMode(.inline)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.background(backgroundView)
		}
		.accessibilityAction(.escape) {
			dismissToShelf()
		}
	}

	private var backgroundView: some View {
		LinearGradient(
			colors: colorScheme == .dark
				? [AppTheme.darkBackgroundTop, AppTheme.darkBackgroundBottom]
				: [AppTheme.lightBackgroundTop, AppTheme.lightBackgroundBottom],
			startPoint: .top,
			endPoint: .bottom
		)
		.ignoresSafeArea()
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

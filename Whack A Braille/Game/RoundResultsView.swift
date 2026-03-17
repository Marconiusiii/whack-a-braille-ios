import SwiftUI

struct RoundResultsView: View {

	let result: RoundResult?
	let totalTickets: Int
	let keepWhacking: () -> Void
	let cashInTickets: () -> Void

	@AccessibilityFocusState private var focusedElement: FocusTarget?

	private enum FocusTarget: Hashable {
		case heading
		case keepWhacking
	}

	var body: some View {
		List {
			Section {
				Text("Round Results")
					.font(.largeTitle.bold())
					.accessibilityAddTraits(.isHeader)
					.accessibilityFocused($focusedElement, equals: .heading)

				Text("Here is how your last round went.")
			}

			if let result {
				Section("Summary") {
					Text("Score: \(result.score)")
					Text("Tickets this round: \(result.totalTickets)")
					Text("Total tickets: \(totalTickets)")
				}

				Section("Bonuses") {
					Text("Hits: \(result.hits)")
					Text("Misses: \(result.misses)")
					Text("Escapes: \(result.escapes)")
					Text("Streak bonuses: \(result.streakBonusTickets)")
					Text("Speed bonuses: \(result.speedBonusTickets)")
				}
			}

			Section("Next") {
				Button("Keep Whacking", action: keepWhacking)
					.buttonStyle(.borderedProminent)
					.accessibilityFocused($focusedElement, equals: .keepWhacking)

				Button("Cash In Tickets", action: cashInTickets)
			}
		}
		.listStyle(.insetGrouped)
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
				focusedElement = .keepWhacking
			}
		}
	}
}

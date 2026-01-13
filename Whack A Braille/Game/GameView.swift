import SwiftUI

struct GameView: View {

	@StateObject private var viewModel = GameViewModel()

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {

			Text("Whack A Braille")
				.font(.title)
				.accessibilityAddTraits(.isHeader)

			// Persistent game status region
			VStack(alignment: .leading, spacing: 8) {
				Text("Score: \(viewModel.score)")
				Text("Streak: \(viewModel.hitStreak)")
				Text(viewModel.isRunning ? "Round in progress" : "Round not running")
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel("Game status")
			.accessibilityValue(
				"Score \(viewModel.score), streak \(viewModel.hitStreak), " +
				(viewModel.isRunning ? "round in progress" : "round not running")
			)

			// Primary control – always present
			Button {
				if viewModel.isRunning {
					viewModel.stopRound()
				} else {
					startTestRound()
				}
			} label: {
				Text(viewModel.isRunning ? "Stop round" : "Start round")
			}

			// Instructional text for screen reader users
			Text("Use braille screen input, a braille display, or a keyboard to hit the moles.")
				.font(.body)

			// Input sink (must exist but must not be focusable)
			BrailleTextInputSinkView(gameLoop: viewModel.gameLoop)
				.frame(width: 1, height: 1)
				.opacity(0.01)
				.accessibilityHidden(true)
		}
		.padding()
	}

	private func startTestRound() {
		let testItems: [BrailleItem] = [
			BrailleItem(id: "a", announceText: "A", dotMask: 0b000001, standardKey: "a"),
			BrailleItem(id: "b", announceText: "B", dotMask: 0b000011, standardKey: "b"),
			BrailleItem(id: "c", announceText: "C", dotMask: 0b000101, standardKey: "c"),
			BrailleItem(id: "d", announceText: "D", dotMask: 0b001101, standardKey: "d"),
			BrailleItem(id: "e", announceText: "E", dotMask: 0b001001, standardKey: "e")
		]

		viewModel.startRound(
			modeId: "test",
			durationSeconds: 30,
			inputMode: .brailleText,
			items: testItems
		)
	}
}

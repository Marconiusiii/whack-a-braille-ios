import SwiftUI

struct GameView: View {

	@StateObject private var viewModel = GameViewModel()

	var body: some View {
		VStack {
			Text("Whack A Braille!")
				.font(.title)

			Text("Score: \(viewModel.score)")
			Text("Streak: \(viewModel.hitStreak)")

			if !viewModel.isRunning {
				Button("Start Round") {
					startTestRound()
				}
			} else {
				Button("Stop Round") {
					viewModel.stopRound()
				}
			}

			// Invisible input sink
			BrailleInputSinkView(gameLoop: viewModel.gameLoop)
				frame(width: 1, height: 1)
				.opacity(0.01)
		}
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

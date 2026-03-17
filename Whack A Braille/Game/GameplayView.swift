import SwiftUI

struct GameplayView: View {

	@ObservedObject var viewModel: GameViewModel
	let inputMode: InputMode
	let isPreparingRound: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 24) {
			Text("Whack the Braille!")
				.font(.largeTitle.bold())
				.accessibilityAddTraits(.isHeader)

			if !viewModel.lastRoundWasTraining {
				Text("Score: \(viewModel.score)")
					.accessibilityLabel("Score \(viewModel.score)")
			}

			HStack(spacing: 12) {
				ForEach(0..<5, id: \.self) { lane in
					RoundedRectangle(cornerRadius: 18)
						.fill(viewModel.activeLane == lane ? Color.accentColor : Color.secondary.opacity(0.2))
						.frame(maxWidth: .infinity, minHeight: 80)
						.accessibilityHidden(true)
				}
			}
			.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: 8) {
				Text("Braille Entry")
					.font(.headline)

				BrailleTextInputSinkView(
					gameLoop: viewModel.gameLoop,
					inputMode: inputMode,
					isEnabled: viewModel.isRunning && !isPreparingRound,
					autoFocus: viewModel.isRunning && !isPreparingRound,
					resetToken: viewModel.inputResetToken
				)
				.frame(height: 48)
			}

			if isPreparingRound {
				HStack(spacing: 12) {
					ProgressView()
					Text("Loading...")
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.padding(20)
	}
}

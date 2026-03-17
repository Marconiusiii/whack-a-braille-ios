import SwiftUI

struct GameplayView: View {

	@ObservedObject var viewModel: GameViewModel
	let inputMode: InputMode
	let stopRound: () -> Void

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				VStack(alignment: .leading, spacing: 12) {
					Text("Whack the Braille!")
						.font(.largeTitle.bold())
						.accessibilityAddTraits(.isHeader)

					Text("Type or chord the target as soon as you hear it.")
				}

				VStack(alignment: .leading, spacing: 10) {
					Text("Score: \(viewModel.score)")
					Text("Streak: \(viewModel.hitStreak)")
					Text("Current target: \(viewModel.activeTargetLabel)")
				}
				.accessibilityElement(children: .contain)
				.accessibilityLabel("Round status")

				HStack(spacing: 12) {
					ForEach(0..<5, id: \.self) { lane in
						RoundedRectangle(cornerRadius: 18)
							.fill(viewModel.activeLane == lane ? Color.accentColor : Color.secondary.opacity(0.2))
							.frame(maxWidth: .infinity, minHeight: 80)
							.overlay {
								Text(viewModel.activeLane == lane ? viewModel.activeTargetLabel : "")
									.font(.headline)
									.foregroundStyle(.white)
							}
							.accessibilityHidden(true)
					}
				}
				.accessibilityHidden(true)

				BrailleTextInputSinkView(
					gameLoop: viewModel.gameLoop,
					inputMode: inputMode,
					isEnabled: viewModel.isRunning,
					autoFocus: viewModel.isRunning
				)
				.frame(height: 48)

				Button("Repeat Current Target") {
					viewModel.repeatCurrentTarget()
				}

				Button("Stop Round", action: stopRound)
			}
			.padding(20)
		}
	}
}

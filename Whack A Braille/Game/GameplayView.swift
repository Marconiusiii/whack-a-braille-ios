import SwiftUI

struct GameplayView: View {

	@ObservedObject var viewModel: GameViewModel
	let inputMode: InputMode
	let brailleSubmitMode: Bool
	let stopRound: () -> Void

	@AccessibilityFocusState private var focusedElement: FocusTarget?

	private enum FocusTarget: Hashable {
		case heading
		case input
	}

	var body: some View {
		List {
			Section {
				Text("Whack Session")
					.font(.largeTitle.bold())
					.accessibilityAddTraits(.isHeader)
					.accessibilityFocused($focusedElement, equals: .heading)

				Text("Listen for the target and enter the matching key or braille cell as quickly as you can.")
			}

			Section("Status") {
				Text("Score: \(viewModel.score)")
				Text("Streak: \(viewModel.hitStreak)")
				Text("Current target: \(viewModel.activeTargetLabel)")
			}

			Section("Game Board") {
				HStack(spacing: 12) {
					ForEach(0..<5, id: \.self) { lane in
						RoundedRectangle(cornerRadius: 18)
							.fill(viewModel.activeLane == lane ? Color.accentColor : Color.secondary.opacity(0.2))
							.frame(maxWidth: .infinity, minHeight: 80)
							.overlay {
								Text(viewModel.activeLane == lane ? viewModel.activeTargetLabel : "")
									.font(.headline)
									foregroundStyle(.white)
							}
							.accessibilityHidden(true)
					}
				}
			}

			Section("Input") {
				BrailleTextInputSinkView(
					gameLoop: viewModel.gameLoop,
					inputMode: inputMode,
					isEnabled: viewModel.isRunning,
					submissionMode: brailleSubmitMode ? .submitKey : .immediate
				)
				.frame(height: 44)
				.accessibilityLabel("Game input field")
				.accessibilityHint("Use Braille Screen Input, a keyboard, or a braille display while the round is active.")
				.accessibilityFocused($focusedElement, equals: .input)
			}

			Section {
				Button("Stop Round", action: stopRound)
			}
		}
		.listStyle(.insetGrouped)
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
				focusedElement = .input
			}
		}
	}
}

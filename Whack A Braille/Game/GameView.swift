import SwiftUI

struct GameView: View {

	@StateObject private var viewModel = GameViewModel()
	@State private var settings = GameSettings()

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {

			Text("Whack A Braille")
				.font(.title)
				.accessibilityAddTraits(.isHeader)

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

			settingsSection

			Button {
				if viewModel.isRunning {
					viewModel.stopRound()
				} else {
					startRoundFromSettings()
				}
			} label: {
				Text(viewModel.isRunning ? "Stop round" : "Start round")
			}

			Text(instructionsText)
				.font(.body)

			// 1) Text sink for BSI, braille displays, and standard keyboard typing
			BrailleTextInputSinkView(
				gameLoop: viewModel.gameLoop,
				isEnabled: true,
				submissionMode: settings.brailleSubmitMode ? .submitKey : .immediate
			)
			.frame(width: 1, height: 1)
			.opacity(0.01)
			.accessibilityHidden(true)

			// 2) Perkins keyboard sink (s/d/f/j/k/l) for immediate dotMask chording
			PerkinsKeyboardSinkView(
				gameLoop: viewModel.gameLoop,
				isEnabled: settings.effectiveKeyboardMode == .perkins
			)
			.frame(width: 1, height: 1)
			.opacity(0.01)
			.accessibilityHidden(true)

			// 3) Touch Perkins pad (true immediate dotMask)
			if settings.touchPadMode != .off {
				let orientation: BraillePadOrientation = (settings.touchPadMode == .tabletop) ? .tabletop : .screenAway

				BraillePadView(
					gameLoop: viewModel.gameLoop,
					isEnabled: true,
					orientation: orientation
				)
				.frame(maxWidth: .infinity, maxHeight: 220)
				.overlay(
					RoundedRectangle(cornerRadius: 16)
						.stroke(Color.secondary, lineWidth: 2)
				)
				.accessibilityLabel("Braille pad")
				.accessibilityHint("Direct touch area for Perkins chording.")
				.accessibilityAddTraits(.allowsDirectInteraction)
			}
		}
		.padding()
	}

	private var settingsSection: some View {
		VStack(alignment: .leading, spacing: 12) {

			Picker("Game set", selection: $settings.modeId) {
				Text("Grade 1: Letters and Numbers").tag("grade1LettersNumbers")
				Text("Grade 2: Symbols").tag("grade2Symbols")
				Text("Grade 2: Word signs").tag("grade2Words")
				Text("Everything").tag("everything")
			}

			Picker("Keyboard input", selection: $settings.keyboardMode) {
				ForEach(KeyboardMode.allCases) { mode in
					Text(mode.label).tag(mode)
				}
			}
			.disabled(settings.isPerkinsLockedByMode)

			Picker("Touch pad", selection: $settings.touchPadMode) {
				ForEach(TouchPadMode.allCases) { mode in
					Text(mode.label).tag(mode)
				}
			}

			Toggle("Braille submit mode (for displays and contracted input)", isOn: $settings.brailleSubmitMode)
		}
	}

	private var instructionsText: String {
		if settings.isPerkinsLockedByMode {
			return "This game set expects Perkins input. Use the braille pad, Perkins home-row keys on a keyboard, or braille input. If using a braille display or contracted input, turn on submit mode."
		}

		if settings.effectiveKeyboardMode == .perkins {
			return "Keyboard is in Perkins mode. Use F D S and J K L as dots 1 through 6."
		}

		return "Type the character using braille input or a keyboard. You can also enable the braille pad or Perkins keyboard mode."
	}

	private func startRoundFromSettings() {
		let modeId = settings.modeId
		let items: [BrailleItem]

		switch modeId {
		case "grade1LettersNumbers":
			items = BrailleRegistry.getItems(for: "grade1LettersNumbers")
		case "grade2Symbols":
			items = BrailleRegistry.getItems(for: "grade2Symbols")
		case "grade2Words":
			items = BrailleRegistry.getItems(for: "grade2Words")
		case "everything":
			items = BrailleRegistry.getItems(for: "everything")
		default:
			items = BrailleRegistry.getItems(for: "grade1LettersNumbers")
		}

		let inputMode: InputMode = settings.isPerkinsLockedByMode ? .perkins : .qwerty

		viewModel.startRound(
			modeId: modeId,
			durationSeconds: 30,
			inputMode: inputMode,
			items: items
		)
	}
}


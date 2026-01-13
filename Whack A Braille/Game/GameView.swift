import SwiftUI
import AVFoundation

struct GameView: View {

	@StateObject private var viewModel = GameViewModel()

	@State private var modeId: String = "grade1LettersNumbers"
	@State private var difficulty: Difficulty = .normal
	@State private var roundDurationSeconds: Int = 30

	@State private var inputMode: InputMode = .qwerty
	@State private var touchPadMode: TouchPadMode = .off
	@State private var brailleSubmitMode: Bool = false

	@State private var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
	@State private var selectedVoiceId: String = "com.apple.ttsbundle.Samantha-compact"

	@AccessibilityFocusState private var isBraillePadFocused: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {

			Text("Whack A Braille")
				.font(.title)
				.accessibilityAddTraits(.isHeader)
				.accessibilityHidden(viewModel.isRunning)

			VStack(alignment: .leading, spacing: 6) {
				Text("Score: \(viewModel.score)")
				Text("Streak: \(viewModel.hitStreak)")
				Text(viewModel.isRunning ? "Round in progress" : "Round not running")
			}
			.accessibilityHidden(viewModel.isRunning)

			VStack(alignment: .leading, spacing: 12) {

				Picker("Game set", selection: $modeId) {
					Text("Grade 1: Letters and Numbers").tag("grade1LettersNumbers")
					Text("Grade 2: Symbols").tag("grade2Symbols")
					Text("Grade 2: Word signs").tag("grade2Words")
					Text("Everything").tag("everything")
				}

				Picker("Difficulty", selection: $difficulty) {
					Text("Beginner").tag(Difficulty.beginner)
					Text("Normal").tag(Difficulty.normal)
					Text("Supreme Mole Whacker").tag(Difficulty.supreme)
				}

				Picker("Round length", selection: $roundDurationSeconds) {
					Text("15 seconds").tag(15)
					Text("30 seconds").tag(30)
					Text("45 seconds").tag(45)
					Text("60 seconds").tag(60)
				}

				Picker("Keyboard input", selection: $inputMode) {
					Text("Standard QWERTY").tag(InputMode.qwerty)
					Text("Perkins (home row)").tag(InputMode.perkins)
				}

				Picker("Touch pad", selection: $touchPadMode) {
					ForEach(TouchPadMode.allCases) { mode in
						Text(mode.label).tag(mode)
					}
				}

				Toggle(
					"Braille submit mode (for displays and contracted input)",
					isOn: $brailleSubmitMode
				)
			}
			.accessibilityHidden(viewModel.isRunning)

			Menu {
				Section("Voice") {
					Picker("Voice", selection: $selectedVoiceId) {
						ForEach(availableVoices, id: \.identifier) { voice in
							Text(voice.name).tag(voice.identifier)
						}
					}
				}

				Section("Rate") {
					Slider(
						value: $speechRate,
						in: 0.4...0.6,
						step: 0.02
					)
					Text("Speech rate")
				}

				Button("Test speech") {
					applySpeechSettings()
					SpeechEngine.shared.speak("Whack A Braille speech test")
				}
			} label: {
				Label("Speech & Audio", systemImage: "speaker.wave.2")
			}
			.accessibilityHidden(viewModel.isRunning)

			Button {
				if viewModel.isRunning {
					viewModel.stopRound()
				} else {
					startRound()
				}
			} label: {
				Text(viewModel.isRunning ? "Stop round" : "Start round")
			}
			.accessibilityHidden(
				viewModel.isRunning && touchPadMode != .off
			)

			BrailleTextInputSinkView(
				gameLoop: viewModel.gameLoop,
				isEnabled: true,
				submissionMode: brailleSubmitMode ? .submitKey : .immediate
			)
			.frame(width: 1, height: 1)
			.opacity(0.01)
			.accessibilityHidden(true)

			if viewModel.isRunning && touchPadMode != .off {
				let orientation: BraillePadOrientation =
					(touchPadMode == .tabletop) ? .tabletop : .screenAway

				BraillePadView(
					gameLoop: viewModel.gameLoop,
					isEnabled: true,
					orientation: orientation
				)
				.frame(maxWidth: .infinity, maxHeight: 240)
				.overlay(
					RoundedRectangle(cornerRadius: 16)
						.stroke(Color.secondary, lineWidth: 2)
				)
				.accessibilityElement(children: .ignore)
				.accessibilityLabel("Braille pad")
				.accessibilityHint("Direct touch area for Perkins chording.")
				.accessibilityAddTraits(.allowsDirectInteraction)
				.accessibilityFocused($isBraillePadFocused)
			}
		}
		.padding()
		.onChange(of: viewModel.isRunning) { running in
			if running && touchPadMode != .off {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					isBraillePadFocused = true
				}
			}
		}
		.onChange(of: selectedVoiceId) { _ in
			applySpeechSettings()
		}
		.onChange(of: speechRate) { _ in
			applySpeechSettings()
		}
	}

	private var availableVoices: [AVSpeechSynthesisVoice] {
		AVSpeechSynthesisVoice.speechVoices()
			.filter { $0.language.hasPrefix("en") }
			.sorted { $0.name < $1.name }
	}

	private func applySpeechSettings() {
		if let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceId) {
			SpeechEngine.shared.setVoice(voice)
		}
		SpeechEngine.shared.setRate(speechRate)
	}

	private func startRound() {
		applySpeechSettings()

		let items = BrailleRegistry.getItems(for: modeId)

		// IMPORTANT:
		// Call GameLoop directly because GameViewModel.startRound does not accept `difficulty:`.
		viewModel.gameLoop.startRound(
			modeId: modeId,
			durationSeconds: roundDurationSeconds,
			inputMode: inputMode,
			difficulty: difficulty,
			itemsForMode: items
		)
	}
}


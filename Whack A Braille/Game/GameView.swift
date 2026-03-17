import AVFoundation
import SwiftUI

struct GameView: View {

	@StateObject private var viewModel = GameViewModel()

	@State private var modeId: String = "grade1LettersNumbers"
	@State private var difficulty: Difficulty = .normal
	@State private var roundDurationSeconds: Int = 30
	@State private var inputMode: InputMode = .qwerty
	@State private var brailleSubmitMode: Bool = false
	@State private var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
	@State private var selectedVoiceId: String = AVSpeechSynthesisVoice(language: "en-US")?.identifier ?? ""

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				Text("Whack A Braille")
					.font(.largeTitle.bold())
					.accessibilityAddTraits(.isHeader)

				scoreboardSection
				boardSection
				inputSection
				settingsSection
				resultsSection
			}
			.padding()
		}
		.onAppear {
			applySpeechSettings()
		}
		.onChange(of: selectedVoiceId) { _ in
			applySpeechSettings()
		}
		.onChange(of: speechRate) { _ in
			applySpeechSettings()
		}
	}

	private var scoreboardSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Score: \(viewModel.score)")
			Text("Streak: \(viewModel.hitStreak)")
			Text(viewModel.isRunning ? "Round in progress" : "Round not running")
		}
		.font(.headline)
		.accessibilityElement(children: .combine)
	}

	private var boardSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Current target: \(viewModel.activeTargetLabel)")
				.font(.title3.weight(.semibold))
				.accessibilityLabel("Current target \(viewModel.activeTargetLabel)")

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

			Text("Focus the input field below for Braille Screen Input, external keyboards, or a connected braille display.")
				.font(.footnote)
				foregroundStyle(.secondary)
		}
	}

	private var inputSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Game Input")
				.font(.headline)

			BrailleTextInputSinkView(
				gameLoop: viewModel.gameLoop,
				inputMode: inputMode,
				isEnabled: viewModel.isRunning,
				submissionMode: brailleSubmitMode ? .submitKey : .immediate
			)
			.frame(height: 44)
			.accessibilityLabel("Game input field")
			.accessibilityHint("Use Braille Screen Input, a keyboard, or a braille display while the round is active.")
		}
	}

	private var settingsSection: some View {
		VStack(alignment: .leading, spacing: 16) {
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
				Text("Standard keyboard").tag(InputMode.qwerty)
				Text("Perkins home row").tag(InputMode.perkins)
			}

			Toggle(
				"Braille submit mode",
				isOn: $brailleSubmitMode
			)

			Menu {
				Section("Voice") {
					Picker("Voice", selection: $selectedVoiceId) {
						Text("System Default").tag("")

						ForEach(availableVoices, id: \.identifier) { voice in
							Text(voice.name).tag(voice.identifier)
						}
					}
				}

				Section("Rate") {
					Slider(value: $speechRate, in: 0.38...0.6, step: 0.02)
					Text("Speech rate")
				}

				Button("Test speech") {
					applySpeechSettings()
					SpeechEngine.shared.speak("Whack A Braille speech test")
				}
			} label: {
				Label("Speech And Audio", systemImage: "speaker.wave.2.fill")
			}

			Button {
				if viewModel.isRunning {
					viewModel.stopRound()
				} else {
					startRound()
				}
			} label: {
				Text(viewModel.isRunning ? "Stop round" : "Start round")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
		}
		.pickerStyle(.menu)
	}

	private var resultsSection: some View {
		Group {
			if let result = viewModel.lastRoundResult {
				VStack(alignment: .leading, spacing: 8) {
					Text("Last round")
						.font(.headline)
					Text("Score: \(result.score)")
					Text("Hits: \(result.hits)")
					Text("Misses: \(result.misses)")
					Text("Escapes: \(result.escapes)")
					Text("Tickets: \(result.totalTickets)")
				}
			}
		}
	}

	private var availableVoices: [AVSpeechSynthesisVoice] {
		AVSpeechSynthesisVoice.speechVoices()
			.filter { $0.language.hasPrefix("en") }
			.sorted { $0.name < $1.name }
	}

	private func applySpeechSettings() {
		if !selectedVoiceId.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceId) {
			SpeechEngine.shared.setVoice(voice)
		}
		SpeechEngine.shared.setRate(speechRate)
	}

	private func startRound() {
		applySpeechSettings()

		viewModel.startRound(
			modeId: modeId,
			durationSeconds: roundDurationSeconds,
			inputMode: inputMode,
			difficulty: difficulty,
			itemsForMode: BrailleRegistry.getItems(for: modeId)
		)
	}
}

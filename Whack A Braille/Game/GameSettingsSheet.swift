import AVFoundation
import SwiftUI

struct GameSettingsSheet: View {

	@Binding var modeId: String
	@Binding var difficulty: Difficulty
	@Binding var roundDurationSeconds: Int
	@Binding var inputMode: InputMode
	@Binding var brailleSubmitMode: Bool
	@Binding var speechRate: Float
	@Binding var selectedVoiceId: String

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			Form {
				Section("Game Set") {
					Picker("Game set", selection: $modeId) {
						Text("Grade 1: Letters and Numbers").tag("grade1LettersNumbers")
						Text("Grade 2: Symbols").tag("grade2Symbols")
						Text("Grade 2: Word signs").tag("grade2Words")
						Text("Everything").tag("everything")
					}
					.pickerStyle(.menu)
				}

				Section("Difficulty") {
					Picker("Difficulty", selection: $difficulty) {
						Text("Beginner").tag(Difficulty.beginner)
						Text("Normal").tag(Difficulty.normal)
						Text("Supreme Mole Whacker").tag(Difficulty.supreme)
					}
					.pickerStyle(.menu)
				}

				Section("Round Length") {
					Picker("Round length", selection: $roundDurationSeconds) {
						Text("15 seconds").tag(15)
						Text("30 seconds").tag(30)
						Text("45 seconds").tag(45)
						Text("60 seconds").tag(60)
					}
					.pickerStyle(.menu)
				}

				Section("Input") {
					Picker("Keyboard input", selection: $inputMode) {
						Text("Standard keyboard").tag(InputMode.qwerty)
						Text("Perkins home row").tag(InputMode.perkins)
					}
					.pickerStyle(.menu)

					Toggle("Braille submit mode", isOn: $brailleSubmitMode)
				}

				Section("Speech") {
					Picker("Voice", selection: $selectedVoiceId) {
						Text("System Default").tag("")

						ForEach(availableVoices, id: \.identifier) { voice in
							Text(voice.name).tag(voice.identifier)
						}
					}
					.pickerStyle(.menu)

					Slider(value: $speechRate, in: 0.38...0.6, step: 0.02)
					Text("Speech rate")
				}
			}
			.navigationTitle("Game Settings")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") {
						dismiss()
					}
				}
			}
		}
	}

	private var availableVoices: [AVSpeechSynthesisVoice] {
		AVSpeechSynthesisVoice.speechVoices()
			.filter { $0.language.hasPrefix("en") }
			.sorted { $0.name < $1.name }
	}
}

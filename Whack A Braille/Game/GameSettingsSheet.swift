import AVFoundation
import SwiftUI
import MessageUI

struct GameSettingsSheet: View {

	@Binding var modeId: String
	@Binding var difficulty: Difficulty
	@Binding var roundDurationSeconds: Int
	@Binding var inputMode: InputMode
	@Binding var timerMusicEnabled: Bool
	@Binding var spatialMoleMappingEnabled: Bool
	@Binding var speakBrailleDots: Bool
	@Binding var characterEcho: Bool
	@Binding var speechRatePercent: Int
	@Binding var selectedVoiceId: String

	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL
	@Environment(\.colorScheme) private var colorScheme

	@State private var isShowingMailComposer = false

	var body: some View {
		NavigationStack {
			Form {
				Section("Mole Chooser") {
					Picker("Mole chooser", selection: $modeId) {
						ForEach(BrailleRegistry.modeOptions, id: \.id) { option in
							Text(option.label).tag(option.id)
						}
					}
				}

				Section("Difficulty") {
					Picker("Difficulty", selection: $difficulty) {
						ForEach(Difficulty.allCases) { level in
							Text(level.label).tag(level)
						}
					}
				}

				Section("Training Options") {
					Toggle("Speak Braille Dots", isOn: $speakBrailleDots)
						.disabled(difficulty != .training)
				}

				Section("Round Length") {
					Picker("Round length", selection: $roundDurationSeconds) {
						Text("30 seconds").tag(30)
						Text("45 seconds").tag(45)
						Text("60 seconds").tag(60)
					}
					.disabled(difficulty == .training)
				}

				Section("Keyboard Input Mode") {
					Picker("Keyboard input mode", selection: $inputMode) {
						ForEach(InputMode.allCases) { mode in
							Text(mode.label).tag(mode)
						}
					}
					.disabled(modeId == "everything")
				}

				Section("Timer Music") {
					Toggle("Enable timer music", isOn: $timerMusicEnabled)
				}

				Section("Spatial Mole Mapping") {
					Toggle("Enable spatial mole mapping", isOn: $spatialMoleMappingEnabled)
				}

				Section("Voice Settings") {
					Picker("System Voice", selection: $selectedVoiceId) {
						Text("System default").tag("")

						ForEach(availableVoices, id: \.identifier) { voice in
							Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
						}
					}

					Toggle("Character Echo", isOn: $characterEcho)

					VStack(alignment: .leading, spacing: 8) {
						Text("Speech Rate: \(speechRatePercent) percent")
							.accessibilityHidden(true)

						Slider(
							value: speechRateBinding,
							in: 5...100,
							step: 5
						)
						.accessibilityLabel("Speech Rate")
						.accessibilityValue("\(speechRatePercent) percent")
					}

					Button("Play Voice Sample") {
						let voice = selectedVoiceId.isEmpty ? nil : AVSpeechSynthesisVoice(identifier: selectedVoiceId)
						SpeechEngine.shared.playVoiceSample(voice: voice, ratePercent: speechRatePercent)
					}

					Button("Send Game Feedback") {
						if MFMailComposeViewController.canSendMail() {
							isShowingMailComposer = true
						} else {
							openMailFallback()
						}
					}
					.accessibilityHint("Opens Mail so you can send feedback about the game.")
				}

				Section {
					Text(appFooterText)
						.font(.footnote)
						.multilineTextAlignment(.center)
						.frame(maxWidth: .infinity, alignment: .center)
						.foregroundStyle(secondaryTextColor)
				}
			}
			.scrollContentBackground(.hidden)
			.background(backgroundView)
			.tint(AppTheme.focus)
			.foregroundStyle(primaryTextColor)
			.navigationTitle("Game Settings")
			.navigationBarTitleDisplayMode(.inline)
			.toolbarBackground(.visible, for: .navigationBar)
			.toolbarBackground(
				colorScheme == .dark ? AppTheme.darkCard : AppTheme.lightCard,
				for: .navigationBar
			)
			.toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") {
						dismiss()
					}
				}
			}
		}
		.sheet(isPresented: $isShowingMailComposer) {
			MailComposerView(
				recipient: "marco@marconius.com",
				subject: "Whack a Braille iOS Feedback",
				body: nil,
				onFinish: { _ in }
			)
		}
		.onAppear {
			UITableView.appearance().backgroundColor = .clear
		}
	}

	private var backgroundView: some View {
		LinearGradient(
			colors: colorScheme == .dark
				? [AppTheme.darkBackgroundTop, AppTheme.darkBackgroundBottom]
				: [AppTheme.lightBackgroundTop, AppTheme.lightBackgroundBottom],
			startPoint: .top,
			endPoint: .bottom
		)
		.ignoresSafeArea()
	}

	private var primaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}

	private var speechRateBinding: Binding<Double> {
		Binding(
			get: { Double(speechRatePercent) },
			set: { speechRatePercent = Int($0.rounded()) }
		)
	}

	private var availableVoices: [AVSpeechSynthesisVoice] {
		let localeLanguage = Locale.current.language.languageCode?.identifier ?? "en"
		let filtered = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.lowercased().hasPrefix(localeLanguage.lowercased()) }
		let source = filtered.isEmpty ? AVSpeechSynthesisVoice.speechVoices() : filtered
		return source.sorted { $0.name < $1.name }
	}

	private var appFooterText: String {
		let year = Calendar.current.component(.year, from: .now)
		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0,0"
		let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
		return "Copyright \(year) By Marco Salsiccia\nv.\(version) (\(build))"
	}

	private func openMailFallback() {
		let subject = "Whack a Braille iOS Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
		guard let mailURL = URL(string: "mailto:marco@marconius.com?subject=\(subject)") else { return }
		openURL(mailURL)
	}
}

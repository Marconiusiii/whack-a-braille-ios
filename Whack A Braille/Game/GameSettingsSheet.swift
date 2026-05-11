import AVFoundation
import MessageUI
import SwiftUI

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
	@Binding var speechVolumePercent: Int
	@Binding var selectedVoiceId: String

	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL
	@Environment(\.colorScheme) private var colorScheme

	@State private var isShowingMailComposer = false

	var body: some View {
		NavigationStack {
			Form {
				Section("Keyboard Input Mode") {
					Picker("Keyboard input mode", selection: $inputMode) {
						ForEach(InputMode.allCases) { mode in
							Text(mode.label).tag(mode)
						}
					}
				}

				Section("Mole Chooser") {
					Picker("Mole chooser", selection: $modeId) {
						ForEach(availableModeOptions, id: \.id) { option in
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

				Section("Timer Music") {
					Toggle("Enable timer music", isOn: $timerMusicEnabled)
				}

				Section("Spatial Mole Mapping") {
					Toggle("Enable spatial mole mapping", isOn: $spatialMoleMappingEnabled)
						.accessibilityHint("Matches mole location with key positions on keyboard.")
				}

				Section("Voice Settings") {
					Picker("System Voice", selection: $selectedVoiceId) {
						Text("System default").tag("")

						ForEach(availableVoices, id: \.identifier) { voice in
							Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
						}
					}

					Toggle("Character Echo", isOn: $characterEcho)
						.accessibilityHint("Speaks NATO word for single letters")

					VStack(alignment: .leading, spacing: 8) {
						Text("Speech Rate: \(speechRatePercent) percent")
							.accessibilityHidden(true)
							.fixedSize(horizontal: false, vertical: true)

						Slider(
							value: speechRateBinding,
							in: 5...100,
							step: 5
						)
						.accessibilityLabel("Speech Rate")
						.accessibilityValue("\(speechRatePercent) percent")
					}

					VStack(alignment: .leading, spacing: 8) {
						Text("Speech Volume: \(speechVolumePercent) percent")
							.accessibilityHidden(true)
							.fixedSize(horizontal: false, vertical: true)

						Slider(
							value: speechVolumeBinding,
							in: 5...100,
							step: 5
						)
						.accessibilityLabel("Speech Volume")
						.accessibilityValue("\(speechVolumePercent) percent")
					}

					Button("Play Voice Sample") {
						let voice = selectedVoiceId.isEmpty ? nil : AVSpeechSynthesisVoice(identifier: selectedVoiceId)
						SpeechEngine.shared.playVoiceSample(
							voice: voice,
							ratePercent: speechRatePercent,
							volumePercent: speechVolumePercent
						)
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

				externalLink(title: "Privacy Policy", url: "https://marconius.com/wabPrivacy/")

				Section {
					Text(appFooterText)
						.font(.footnote)
						.multilineTextAlignment(.center)
						.frame(maxWidth: .infinity, alignment: .center)
						.foregroundStyle(secondaryTextColor)
				}
			}
			.scrollContentBackground(.hidden)
			.listSectionSpacing(20)
			.background(backgroundView)
			.tint(AppTheme.focus)
			.foregroundStyle(primaryTextColor)
			.environment(\.defaultMinListRowHeight, 54)
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
			sanitizeModeSelection()
		}
		.onChange(of: inputMode) { _, _ in
			sanitizeModeSelection()
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

	private var speechVolumeBinding: Binding<Double> {
		Binding(
			get: { Double(speechVolumePercent) },
			set: { speechVolumePercent = Int($0.rounded()) }
		)
	}

	private var availableModeOptions: [BrailleRegistry.ModeOption] {
		BrailleRegistry.filteredModeOptions(for: inputMode)
	}

	private var availableVoices: [AVSpeechSynthesisVoice] {
		let localeLanguage = Locale.current.language.languageCode?.identifier ?? "en"
		let filtered = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.lowercased().hasPrefix(localeLanguage.lowercased()) }
		let source = filtered.isEmpty ? AVSpeechSynthesisVoice.speechVoices() : filtered
		return source.sorted { lhs, rhs in
			let lhsRank = voiceSortRank(for: lhs)
			let rhsRank = voiceSortRank(for: rhs)

			if lhsRank != rhsRank {
				return lhsRank < rhsRank
			}

			if lhs.name != rhs.name {
				return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
			}

			return lhs.language.localizedCaseInsensitiveCompare(rhs.language) == .orderedAscending
		}
	}

	private func voiceSortRank(for voice: AVSpeechSynthesisVoice) -> Int {
		let qualityRank: Int

		switch voice.quality {
		case .premium:
			qualityRank = 0
		case .enhanced:
			qualityRank = 1
		default:
			qualityRank = 2
		}

		let noveltyPenalty: Int
		if #available(iOS 17.0, *) {
			noveltyPenalty = voice.voiceTraits.contains(.isNoveltyVoice) ? 10 : 0
		} else {
			noveltyPenalty = 0
		}

		return qualityRank + noveltyPenalty
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

	private func externalLink(title: String, url: String) -> some View {
		Link(title, destination: URL(string: url)!)
			.font(.body)
			.foregroundStyle(secondaryTextColor)
			.underline()
			.accessibilityTouchRegion(minHeight: 60, verticalPadding: 4, alignment: .leading)
			.accessibilityAddTraits(.isLink)
			.accessibilityRemoveTraits(.isButton)
			.accessibilityHint("Opens in external browser")
	}

	private func sanitizeModeSelection() {
		modeId = BrailleRegistry.sanitizedModeId(modeId, for: inputMode)
	}
}

import AVFoundation
import MessageUI
import StoreKit
import SwiftUI

struct GameSettingsSheet: View {

	@Binding var modeId: String
	@Binding var difficulty: Difficulty
	@Binding var roundDurationSeconds: Int
	@Binding var inputMode: InputMode
	@Binding var timerMusicEnabled: Bool
	@Binding var gameAudioModeRawValue: String
	@Binding var spatialMoleMappingEnabled: Bool
	@Binding var speakBrailleDots: Bool
	@Binding var characterEcho: Bool
	@Binding var speechRatePercent: Int
	@Binding var speechVolumePercent: Int
	@Binding var selectedVoiceId: String
	@Binding var customMolePlayModeRawValue: String
	@Binding var customIndividualMoleIDs: String
	@Binding var customInvasionMoleIDs: String

	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL
	@Environment(\.colorScheme) private var colorScheme
	@AccessibilityFocusState private var focusedElement: FocusTarget?
	@StateObject private var supportStore = SupportStore.shared

	@State private var isShowingMailComposer = false
	@State private var isShowingCustomMolePicker = false
	@State private var isShowingAcknowledgments = false
	@State private var shouldRestoreCustomMoleFocus = false
	@State private var shouldSkipNextModeFocusRestore = false
	@State private var cachedVoices: [AVSpeechSynthesisVoice] = []

	private enum FocusTarget: Hashable {
		case keyboardInputModePicker
		case moleChooserPicker
		case difficultyPicker
		case speakBrailleDotsToggle
		case roundLengthPicker
		case timerMusicToggle
		case gameSoundsPicker
		case spatialMoleMappingToggle
		case systemVoicePicker
		case characterEchoToggle
		case speechRateSlider
		case speechVolumeSlider
		case voiceSampleButton
		case supportConfirmation
		case sendFeedbackButton
		case customMolePickerButton
		case acknowledgmentsButton
	}

	var body: some View {
		NavigationStack {
			Form {
				Section("Gameplay") {
					Picker("Keyboard input mode", selection: $inputMode) {
						ForEach(InputMode.allCases) { mode in
							Text(mode.label).tag(mode)
						}
					}
					.accessibilityFocused($focusedElement, equals: .keyboardInputModePicker)

					Picker("Mole chooser", selection: $modeId) {
						ForEach(availableModeOptions, id: \.id) { option in
							Text(option.label).tag(option.id)
						}
					}
					.accessibilityFocused($focusedElement, equals: .moleChooserPicker)

					if modeId == "customMoles" {
						Button {
							isShowingCustomMolePicker = true
						} label: {
							Text("Pick Custom Moles...")
								.fixedSize(horizontal: false, vertical: true)
						}
						.accessibilityTouchRegion(minHeight: 54, alignment: .leading)
						.accessibilityFocused($focusedElement, equals: .customMolePickerButton)
					}

					Picker("Difficulty", selection: $difficulty) {
						ForEach(Difficulty.allCases) { level in
							Text(level.label).tag(level)
						}
					}
					.accessibilityFocused($focusedElement, equals: .difficultyPicker)

					Picker("Round length", selection: $roundDurationSeconds) {
						Text("30 seconds").tag(30)
						Text("45 seconds").tag(45)
						Text("60 seconds")
							.tag(60)
							.accessibilityHint("Does it ever stop?")
					}
					.disabled(difficulty == .training)
					.accessibilityFocused($focusedElement, equals: .roundLengthPicker)
				}

				Section("Training") {
					Toggle("Speak Braille Dots", isOn: $speakBrailleDots)
						.disabled(difficulty != .training)
						.accessibilityFocused($focusedElement, equals: .speakBrailleDotsToggle)
				}

				Section("Audio") {
					Toggle("Enable timer music", isOn: $timerMusicEnabled)
						.accessibilityFocused($focusedElement, equals: .timerMusicToggle)

					Picker("Game sounds", selection: $gameAudioModeRawValue) {
						ForEach(GameAudioMode.allCases) { mode in
							Text(mode.label).tag(mode.rawValue)
						}
					}
					.accessibilityFocused($focusedElement, equals: .gameSoundsPicker)

					Toggle("Enable spatial mole mapping", isOn: $spatialMoleMappingEnabled)
						.accessibilityHint("Matches mole location with key positions on keyboard.")
						.accessibilityFocused($focusedElement, equals: .spatialMoleMappingToggle)
				}

				Section("Speech") {
					Picker("System Voice", selection: $selectedVoiceId) {
						Text("System default").tag("")

						ForEach(availableVoices, id: \.identifier) { voice in
							Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
						}
					}
					.accessibilityFocused($focusedElement, equals: .systemVoicePicker)

					Toggle("Character Echo", isOn: $characterEcho)
						.accessibilityHint("Speaks NATO word for single letters")
						.accessibilityFocused($focusedElement, equals: .characterEchoToggle)

					VStack(alignment: .leading, spacing: 0) {
						Text("Speech Rate: \(speechRatePercent) percent")
							.accessibilityHidden(true)
							.fixedSize(horizontal: false, vertical: true)
							.accessibilityTouchRegion(minHeight: 0, topPadding: 0, bottomPadding: 8, alignment: .leading)

						Slider(
							value: speechRateBinding,
							in: 5...100,
							step: 5
						)
						.accessibilityLabel("Speech Rate")
						.accessibilityValue("\(speechRatePercent) percent")
						.accessibilityTouchRegion(minHeight: 44, alignment: .leading)
						.accessibilityFocused($focusedElement, equals: .speechRateSlider)
					}
					.accessibilityTouchRegion(minHeight: 72, alignment: .leading)

					VStack(alignment: .leading, spacing: 0) {
						Text("Speech Volume: \(speechVolumePercent) percent")
							.accessibilityHidden(true)
							.fixedSize(horizontal: false, vertical: true)
							.accessibilityTouchRegion(minHeight: 0, topPadding: 0, bottomPadding: 8, alignment: .leading)

						Slider(
							value: speechVolumeBinding,
							in: 5...100,
							step: 5
						)
						.accessibilityLabel("Speech Volume")
						.accessibilityValue("\(speechVolumePercent) percent")
						.accessibilityTouchRegion(minHeight: 44, alignment: .leading)
						.accessibilityFocused($focusedElement, equals: .speechVolumeSlider)
					}
					.accessibilityTouchRegion(minHeight: 72, alignment: .leading)

					Button {
						let voice = selectedVoiceId.isEmpty ? nil : AVSpeechSynthesisVoice(identifier: selectedVoiceId)
						SpeechEngine.shared.playVoiceSample(
							voice: voice,
							ratePercent: speechRatePercent,
							volumePercent: speechVolumePercent
						)
					} label: {
						Text("Play Voice Sample")
							.fixedSize(horizontal: false, vertical: true)
					}
					.accessibilityTouchRegion(minHeight: 54, alignment: .leading)
					.accessibilityFocused($focusedElement, equals: .voiceSampleButton)

				}

				supportSection

				Section("About and Feedback") {
					Button {
						if MFMailComposeViewController.canSendMail() {
							isShowingMailComposer = true
						} else {
							openMailFallback()
							restoreFocus(to: .sendFeedbackButton)
						}
					} label: {
						Text("Send Game Feedback")
							.fixedSize(horizontal: false, vertical: true)
					}
					.accessibilityTouchRegion(minHeight: 54, alignment: .leading)
					.accessibilityHint("Opens Mail so you can send feedback about the game.")
					.accessibilityFocused($focusedElement, equals: .sendFeedbackButton)

					Button("Acknowledgments") {
						isShowingAcknowledgments = true
					}
					.accessibilityTouchRegion(minHeight: 54, alignment: .leading)
					.accessibilityHint("Opens word list credits and license acknowledgments.")
					.accessibilityFocused($focusedElement, equals: .acknowledgmentsButton)

					externalLink(title: "Privacy Policy", url: "https://marconius.com/wabPrivacy/")

					Text(appFooterText)
						.font(.footnote)
						.multilineTextAlignment(.center)
						.fixedSize(horizontal: false, vertical: true)
						.frame(maxWidth: .infinity, alignment: .center)
						.foregroundStyle(secondaryTextColor)
						.accessibilityTouchRegion(minHeight: 60)
				}
			}
			.scrollContentBackground(.hidden)
			.listSectionSpacing(0)
			.background(backgroundView)
			.tint(AppTheme.focus)
			.foregroundStyle(primaryTextColor)
			.environment(\.defaultMinListRowHeight, 60)
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
		.sheet(
			isPresented: $isShowingCustomMolePicker,
			onDismiss: restoreCustomMolePickerFocusIfNeeded
		) {
			CustomMolePickerSheet(
				inputMode: inputMode,
				playModeRawValue: $customMolePlayModeRawValue,
				individualMoleIDs: $customIndividualMoleIDs,
				invasionMoleIDs: $customInvasionMoleIDs,
				onDismissRequest: {
					shouldRestoreCustomMoleFocus = true
				}
			)
		}
		.sheet(
			isPresented: $isShowingAcknowledgments,
			onDismiss: {
				restoreFocus(to: .acknowledgmentsButton)
			}
		) {
			AcknowledgmentsView()
		}
		.sheet(
			isPresented: $isShowingMailComposer,
			onDismiss: {
				restoreFocus(to: .sendFeedbackButton)
			}
		) {
			MailComposerView(
				recipient: "marco@marconius.com",
				subject: "Whack a Braille iOS Feedback",
				body: nil,
				onFinish: { _ in }
			)
		}
		.onAppear {
			UITableView.appearance().backgroundColor = .clear
			refreshCachedVoices()
			sanitizeModeSelection()
		}
		.task {
			await supportStore.loadProducts()
		}
		.onChange(of: inputMode) { _, _ in
			shouldSkipNextModeFocusRestore = sanitizeModeSelection()
			restoreFocus(to: .keyboardInputModePicker)
		}
		.onChange(of: modeId) { _, _ in
			if shouldSkipNextModeFocusRestore {
				shouldSkipNextModeFocusRestore = false
				return
			}

			restoreFocus(to: .moleChooserPicker)
		}
		.onChange(of: difficulty) { _, _ in
			restoreFocus(to: .difficultyPicker)
		}
		.onChange(of: speakBrailleDots) { _, _ in
			restoreFocus(to: .speakBrailleDotsToggle)
		}
		.onChange(of: roundDurationSeconds) { _, _ in
			restoreFocus(to: .roundLengthPicker)
		}
		.onChange(of: timerMusicEnabled) { _, _ in
			restoreFocus(to: .timerMusicToggle)
		}
		.onChange(of: gameAudioModeRawValue) { _, _ in
			restoreFocus(to: .gameSoundsPicker)
		}
		.onChange(of: spatialMoleMappingEnabled) { _, _ in
			restoreFocus(to: .spatialMoleMappingToggle)
		}
		.onChange(of: selectedVoiceId) { _, _ in
			restoreFocus(to: .systemVoicePicker)
		}
		.onChange(of: characterEcho) { _, _ in
			restoreFocus(to: .characterEchoToggle)
		}
		.onChange(of: speechRatePercent) { _, _ in
			restoreFocus(to: .speechRateSlider)
		}
		.onChange(of: speechVolumePercent) { _, _ in
			restoreFocus(to: .speechVolumeSlider)
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
		cachedVoices
	}

	private var supportSection: some View {
		Section("Support Whack A Braille") {
			VStack(alignment: .leading, spacing: 8) {
				Text("Toss in a few tokens to support future bonks, prize nonsense, and the Developer's coffee addiction!")
					.fixedSize(horizontal: false, vertical: true)

				if let latestThankYou = supportStore.latestThankYou {
					Text("Thanks for the \(latestThankYou.supportName) on \(supportDateFormatter.string(from: latestThankYou.date)).")
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityFocused($focusedElement, equals: .supportConfirmation)
				}
			}
			.accessibilityTouchRegion(minHeight: 72, alignment: .leading)

			ForEach(SupportStore.supportOptions) { option in
				Button {
					Task {
						await supportStore.purchase(option)
						if case .success = supportStore.status {
							restoreFocus(to: .supportConfirmation)
						}
					}
				} label: {
					VStack(alignment: .leading, spacing: 4) {
						Text(option.fallbackName)
							.fixedSize(horizontal: false, vertical: true)
						Text(supportPriceText(for: option))
							.foregroundStyle(secondaryTextColor)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.disabled(!canPurchase(option))
				.accessibilityLabel("\(option.fallbackName), \(supportPriceText(for: option))")
				.accessibilityTouchRegion(minHeight: 60, alignment: .leading)
			}

			if let statusText = supportStatusText {
				Text(statusText)
					.foregroundStyle(secondaryTextColor)
					.fixedSize(horizontal: false, vertical: true)
					.accessibilityTouchRegion(minHeight: 54, alignment: .leading)
					.accessibilityFocused($focusedElement, equals: .supportConfirmation)
			}
		}
	}

	private var supportStatusText: String? {
		switch supportStore.status {
		case .idle:
			return nil
		case .loading:
			return "Loading support options..."
		case .purchasing(let name):
			return "Sending \(name) through the token slot..."
		case .success:
			return "Thanks for supporting Whack A Braille. The moles are pretending not to be impressed."
		case .pending:
			return "The arcade cashier is counting slowly. Your support is still pending."
		case .failed(let message):
			return message
		}
	}

	private var supportDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateStyle = .long
		formatter.timeStyle = .none
		return formatter
	}

	private func canPurchase(_ option: SupportStore.SupportOption) -> Bool {
		guard supportStore.product(for: option) != nil else { return false }

		if case .purchasing = supportStore.status {
			return false
		}

		return true
	}

	private func supportPriceText(for option: SupportStore.SupportOption) -> String {
		supportStore.product(for: option)?.displayPrice ?? option.fallbackPrice
	}

	private func refreshCachedVoices() {
		let localeLanguage = Locale.current.language.languageCode?.identifier ?? "en"
		let filtered = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.lowercased().hasPrefix(localeLanguage.lowercased()) }
		let source = filtered.isEmpty ? AVSpeechSynthesisVoice.speechVoices() : filtered

		cachedVoices = source.sorted { lhs, rhs in
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

	@discardableResult
	private func sanitizeModeSelection() -> Bool {
		let sanitizedModeId = BrailleRegistry.sanitizedModeId(modeId, for: inputMode)
		guard modeId != sanitizedModeId else { return false }
		modeId = sanitizedModeId
		return true
	}

	private func restoreCustomMolePickerFocusIfNeeded() {
		guard shouldRestoreCustomMoleFocus else { return }
		shouldRestoreCustomMoleFocus = false
		restoreFocus(to: .customMolePickerButton)
	}

	private func restoreFocus(to target: FocusTarget) {
		focusedElement = nil

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			focusedElement = target
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
			focusedElement = target
		}
	}
}

private struct CustomMolePickerSheet: View {

	@Environment(\.dismiss) private var dismiss
	@AccessibilityFocusState private var focusedElement: FocusTarget?
	@Binding private var playModeRawValue: String
	@Binding private var individualMoleIDs: String
	@Binding private var invasionMoleIDs: String

	let inputMode: InputMode
	let onDismissRequest: () -> Void

	@State private var localMode: CustomMolePlayMode
	@State private var selectedIndividualIDs: [String]
	@State private var selectedInvasionIDs: Set<String>
	@State private var selectedSlot: MoleSelectionSlot?
	@State private var pendingSlotFocusIndex: Int?
	@State private var isShowingMinimumAlert = false

	private enum FocusTarget: Hashable {
		case playModePicker
		case individualMole(Int)
		case invasionAction(String)
		case invasionMole(String)
	}

	private let sections: [BrailleRegistry.CustomMoleSection]
	private let allItems: [BrailleItem]

	init(
		inputMode: InputMode,
		playModeRawValue: Binding<String>,
		individualMoleIDs: Binding<String>,
		invasionMoleIDs: Binding<String>,
		onDismissRequest: @escaping () -> Void
	) {
		self.inputMode = inputMode
		self._playModeRawValue = playModeRawValue
		self._individualMoleIDs = individualMoleIDs
		self._invasionMoleIDs = invasionMoleIDs
		self.onDismissRequest = onDismissRequest

		let sections = BrailleRegistry.customMoleSections(for: inputMode)
		let allItems = sections.flatMap(\.items)
		self.sections = sections
		self.allItems = allItems

		let mode = CustomMolePlayMode(rawValue: playModeRawValue.wrappedValue) ?? .individual
		self._localMode = State(initialValue: mode)
		self._selectedIndividualIDs = State(initialValue: Self.normalizedIndividualIDs(individualMoleIDs.wrappedValue, allItems: allItems))
		self._selectedInvasionIDs = State(initialValue: Self.normalizedInvasionIDs(invasionMoleIDs.wrappedValue, allItems: allItems))
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					Text("Pick the moles you most want to bash, or build your own Invasion!")
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityTouchRegion(minHeight: 60, alignment: .leading)
				}

				Section {
					Picker("Custom mole picker mode", selection: $localMode) {
						ForEach(CustomMolePlayMode.allCases) { mode in
							Text(mode.label).tag(mode)
						}
					}
					.pickerStyle(.segmented)
					.accessibilityTouchRegion(minHeight: 60, alignment: .leading)
					.accessibilityFocused($focusedElement, equals: .playModePicker)
				}

				if localMode == .individual {
					individualMolesSection
				} else {
					invasionArmySections
				}
			}
			.navigationTitle("Custom Mole Picker")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						onDismissRequest()
						dismiss()
					}
				}

				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveCustomMoles()
					}
				}
			}
			.alert("You have to choose at least 5 moles for the whacking can commence!", isPresented: $isShowingMinimumAlert) {
				Button("OK", role: .cancel) {
					restoreFocusAfterMinimumAlert()
				}
			}
			.sheet(
				item: $selectedSlot,
				onDismiss: restoreSelectedSlotFocusIfNeeded
			) { slot in
				MoleSelectionSheet(
					title: "Choose Mole \(slot.index + 1)",
					sections: sections,
					selectedID: selectedIndividualIDs[slot.index],
					selectMole: { itemID in
						selectedIndividualIDs[slot.index] = itemID
						pendingSlotFocusIndex = slot.index
						selectedSlot = nil
					}
				)
			}
			.onChange(of: localMode) { _, newMode in
				restoreFocus(to: newMode == .individual ? .individualMole(0) : .playModePicker)
			}
		}
	}

	private var individualMolesSection: some View {
		Section {
			Text("Choose 5 moles to whack!")
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityTouchRegion(minHeight: 54, alignment: .leading)

			ForEach(0..<selectedIndividualIDs.count, id: \.self) { index in
				Button {
					pendingSlotFocusIndex = index
					selectedSlot = MoleSelectionSlot(index: index)
				} label: {
					HStack {
						Text("Mole \(index + 1)")
						Spacer()
						Text(label(for: selectedIndividualIDs[index]))
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.trailing)
					}
				}
				.accessibilityLabel("Mole \(index + 1), \(label(for: selectedIndividualIDs[index]))")
				.accessibilityHint("Opens a searchable mole list.")
				.accessibilityTouchRegion(minHeight: 60, alignment: .leading)
				.accessibilityFocused($focusedElement, equals: .individualMole(index))
			}
		}
	}

	@ViewBuilder
	private var invasionArmySections: some View {
		Section {
			Text("Recruit all the moles you wish to whack!")
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityTouchRegion(minHeight: 54, alignment: .leading)

			Text("\(selectedInvasionIDs.count) moles selected")
				.foregroundStyle(.secondary)
				.accessibilityTouchRegion(minHeight: 44, alignment: .leading)

			VStack(spacing: 0) {
				HStack(spacing: 12) {
					invasionArmyActionButton("Select All") {
						selectedInvasionIDs = Set(allItems.map(\.id))
						restoreFocus(to: .invasionAction("Select All"))
					}
					.accessibilityFocused($focusedElement, equals: .invasionAction("Select All"))

					invasionArmyActionButton("Clear All") {
						selectedInvasionIDs = []
						restoreFocus(to: .invasionAction("Clear All"))
					}
					.accessibilityFocused($focusedElement, equals: .invasionAction("Clear All"))
				}

				HStack(spacing: 12) {
					invasionArmyActionButton("Clear Grade 1") {
						clearInvasionMoles(matchingSectionIDs: ["grade1Letters", "grade1Numbers"])
						restoreFocus(to: .invasionAction("Clear Grade 1"))
					}
					.accessibilityFocused($focusedElement, equals: .invasionAction("Clear Grade 1"))

					invasionArmyActionButton("Clear Grade 2") {
						clearInvasionMoles(matchingSectionIDs: [
							"grade2Symbols",
							"grade2Words",
							"grade2Shortforms",
							"grade2Dot5Initials",
							"grade2Dot45Initials",
							"grade2Suffixes",
							"grade2Dot456Initials"
						])
						restoreFocus(to: .invasionAction("Clear Grade 2"))
					}
					.accessibilityFocused($focusedElement, equals: .invasionAction("Clear Grade 2"))
				}
			}
		}

		ForEach(sections) { section in
			Section(section.title) {
				ForEach(section.items, id: \.id) { item in
					Button {
						toggleInvasionMole(item.id)
						restoreFocus(to: .invasionMole(item.id))
					} label: {
						HStack {
							Image(systemName: selectedInvasionIDs.contains(item.id) ? "checkmark.square.fill" : "square")
								.accessibilityHidden(true)
							Text(item.displayLabel)
							Spacer()
						}
					}
					.accessibilityLabel(item.displayLabel)
					.accessibilityValue(selectedInvasionIDs.contains(item.id) ? "Selected" : "Not selected")
					.accessibilityHint("Toggles this mole in your Invasion Army.")
					.accessibilityTouchRegion(minHeight: 54, alignment: .leading)
					.accessibilityFocused($focusedElement, equals: .invasionMole(item.id))
				}
			}
		}
	}

	private func saveCustomMoles() {
		guard selectedCount >= 5 else {
			isShowingMinimumAlert = true
			return
		}

		playModeRawValue = localMode.rawValue
		individualMoleIDs = selectedIndividualIDs.joined(separator: ",")
		invasionMoleIDs = selectedInvasionIDs.sorted().joined(separator: ",")
		onDismissRequest()
		dismiss()
	}

	private var selectedCount: Int {
		switch localMode {
		case .individual:
			return selectedIndividualIDs.count
		case .invasion:
			return selectedInvasionIDs.count
		}
	}

	private func toggleInvasionMole(_ id: String) {
		if selectedInvasionIDs.contains(id) {
			selectedInvasionIDs.remove(id)
		} else {
			selectedInvasionIDs.insert(id)
		}
	}

	private func clearInvasionMoles(matchingSectionIDs sectionIDs: Set<String>) {
		let idsToClear = sections
			.filter { sectionIDs.contains($0.id) }
			.flatMap(\.items)
			.map(\.id)

		selectedInvasionIDs.subtract(idsToClear)
	}

	private func invasionArmyActionButton(_ title: String, action: @escaping () -> Void) -> some View {
		Button(title, action: action)
			.frame(maxWidth: .infinity, alignment: .leading)
			.accessibilityTouchRegion(minHeight: 54, alignment: .leading)
	}

	private func restoreSelectedSlotFocusIfNeeded() {
		guard let pendingSlotFocusIndex else { return }
		self.pendingSlotFocusIndex = nil
		restoreFocus(to: .individualMole(pendingSlotFocusIndex))
	}

	private func restoreFocusAfterMinimumAlert() {
		switch localMode {
		case .individual:
			restoreFocus(to: .individualMole(0))
		case .invasion:
			restoreFocus(to: .playModePicker)
		}
	}

	private func restoreFocus(to target: FocusTarget) {
		focusedElement = nil

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			focusedElement = target
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
			focusedElement = target
		}
	}

	private func label(for id: String) -> String {
		allItems.first(where: { $0.id == id })?.displayLabel ?? id
	}

	private static func normalizedIndividualIDs(_ rawValue: String, allItems: [BrailleItem]) -> [String] {
		let validIDs = Set(allItems.map(\.id))
		let storedIDs = decodedIDs(rawValue).filter { validIDs.contains($0) }
		let defaultIDs = allItems.prefix(5).map(\.id)

		return (0..<5).compactMap { index in
			if storedIDs.indices.contains(index) {
				return storedIDs[index]
			}

			if defaultIDs.indices.contains(index) {
				return defaultIDs[index]
			}

			return nil
		}
	}

	private static func normalizedInvasionIDs(_ rawValue: String, allItems: [BrailleItem]) -> Set<String> {
		let allIDs = allItems.map(\.id)
		let validIDs = Set(allIDs)
		let storedIDs = decodedIDs(rawValue).filter { validIDs.contains($0) }

		if storedIDs.isEmpty {
			return Set(allIDs)
		}

		return Set(storedIDs)
	}

	private static func decodedIDs(_ rawValue: String) -> [String] {
		rawValue
			.split(separator: ",")
			.map(String.init)
			.filter { !$0.isEmpty }
	}
}

private struct MoleSelectionSlot: Identifiable {
	let index: Int
	var id: Int { index }
}

private struct MoleSelectionSheet: View {

	@Environment(\.dismiss) private var dismiss
	@State private var searchText = ""

	let title: String
	let sections: [BrailleRegistry.CustomMoleSection]
	let selectedID: String
	let selectMole: (String) -> Void

	var body: some View {
		NavigationStack {
			List {
				ForEach(filteredSections) { section in
					Section(section.title) {
						ForEach(section.items, id: \.id) { item in
							Button {
								selectMole(item.id)
								dismiss()
							} label: {
								HStack {
									Text(item.displayLabel)
									Spacer()
									if item.id == selectedID {
										Image(systemName: "checkmark")
											.accessibilityHidden(true)
									}
								}
							}
							.accessibilityLabel(item.displayLabel)
							.accessibilityValue(item.id == selectedID ? "Selected" : "Not selected")
							.accessibilityHint("Selects this mole for the custom mole slot.")
							.accessibilityTouchRegion(minHeight: 54, alignment: .leading)
						}
					}
				}
			}
			.navigationTitle(title)
			.navigationBarTitleDisplayMode(.inline)
			.searchable(text: $searchText, prompt: "Search moles")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
			}
		}
	}

	private var filteredSections: [BrailleRegistry.CustomMoleSection] {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return sections }

		return sections
			.map { section in
				BrailleRegistry.CustomMoleSection(
					id: section.id,
					title: section.title,
					items: section.items.filter { item in
						item.displayLabel.localizedCaseInsensitiveContains(query)
							|| item.announceText.localizedCaseInsensitiveContains(query)
					}
				)
			}
			.filter { !$0.items.isEmpty }
	}
}

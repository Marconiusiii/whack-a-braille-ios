import AVFoundation
import SwiftUI
import UIKit

struct GameView: View {

	private enum CashOutOrigin {
		case home
		case roundResults
	}

	private let invasionIntroPhrases = [
		"Incoming moles!",
		"Invasion Incoming!",
		"Mole Invasion, Oh no!",
		"Prepare for Moles!",
		"So many moles!",
		"Here comes the mole stampede!",
		"The moles are on the move!",
		"Brace yourself for moles!",
		"Grade 2 moles, everywhere!",
		"Moles incoming from all sides!"
	]

	@StateObject private var viewModel = GameViewModel()

	@AppStorage("whackABraille.modeId") private var modeId = "grade1Letters"
	@AppStorage("whackABraille.difficulty") private var difficultyRawValue = Difficulty.normal.rawValue
	@AppStorage("whackABraille.roundDurationSeconds") private var roundDurationSeconds = 30
	@AppStorage("whackABraille.inputMode") private var inputModeRawValue = InputMode.qwerty.rawValue
	@AppStorage("whackABraille.timerMusicEnabled") private var timerMusicEnabled = true
	@AppStorage("whackABraille.gameAudioMode") private var gameAudioModeRawValue = GameAudioMode.original.rawValue
	@AppStorage("whackABraille.spatialMoleMappingEnabled") private var spatialMoleMappingEnabled = true
	@AppStorage("whackABraille.speakBrailleDots") private var speakBrailleDots = false
	@AppStorage("whackABraille.characterEcho") private var characterEcho = false
	@AppStorage("whackABraille.speechRatePercent") private var speechRatePercent = 35
	@AppStorage("whackABraille.speechVolumePercent") private var speechVolumePercent = 85
	@AppStorage("whackABraille.selectedVoiceId") private var selectedVoiceId = ""
	@AppStorage("whackABraille.customMolePlayMode") private var customMolePlayModeRawValue = CustomMolePlayMode.individual.rawValue
	@AppStorage("whackABraille.customIndividualMoleIDs") private var customIndividualMoleIDs = ""
	@AppStorage("whackABraille.customInvasionMoleIDs") private var customInvasionMoleIDs = ""

	@State private var isShowingSettings = false
	@State private var isShowingCashOut = false
	@State private var isShowingHowToPlay = false
	@State private var shouldRestoreHowToPlayFocus = false
	@State private var cashOutOrigin: CashOutOrigin = .roundResults
	@State private var pendingRoundStartID = UUID()
	@State private var lastTrainingOptions: GameLoop.Options?
	@State private var lastMoleReconContext: MoleReconTrainingContext?

	var body: some View {
		Group {
			switch viewModel.phase {
			case .home:
				HomeView(
						totalTickets: viewModel.totalAccruedTickets,
						prizeShelfItems: viewModel.prizeShelfItems,
						prizeShelfCount: viewModel.prizeShelfCount,
							homeHeadingFocusToken: viewModel.homeHeadingFocusToken,
							howToPlayFocusToken: viewModel.howToPlayFocusToken,
							gameSettingsFocusToken: viewModel.gameSettingsFocusToken,
							cashInFocusToken: viewModel.cashInFocusToken,
							openHowToPlay: { isShowingHowToPlay = true },
					openPrizeCounter: openPrizeCounter,
					openSettings: { isShowingSettings = true },
					startGame: startRound,
					clearPrizeShelf: viewModel.clearPrizeShelf,
					removePrizeShelfItem: viewModel.removePrizeShelfItem
				)
			case .gameplay:
				GameplayView(
					viewModel: viewModel,
					inputMode: effectiveInputMode,
					gameplayFocusToken: viewModel.gameplayFocusToken,
					speakBrailleDots: $speakBrailleDots,
					exitGame: viewModel.exitRoundToResults
				)
			case .roundResults:
				RoundResultsView(
					result: viewModel.lastRoundResult,
					totalTickets: viewModel.totalAccruedTickets,
					moleReconContext: lastMoleReconContext,
					keepWhacking: keepWhackingFromResults,
					beginMoleRecon: startMoleRecon,
					cashInTickets: cashInTickets,
					saveTicketsAndReturnHome: viewModel.saveTicketsAndReturnHome,
					returnHome: returnHomeFromResults,
					speakBrailleDots: $speakBrailleDots
				)
			}
		}
		.id(viewIdentity)
			.sheet(
				isPresented: $isShowingSettings,
				onDismiss: viewModel.returnFocusToGameSettings
			) {
				GameSettingsSheet(
				modeId: $modeId,
				difficulty: difficultyBinding,
				roundDurationSeconds: $roundDurationSeconds,
				inputMode: inputModeBinding,
				timerMusicEnabled: $timerMusicEnabled,
				gameAudioModeRawValue: $gameAudioModeRawValue,
				spatialMoleMappingEnabled: $spatialMoleMappingEnabled,
				speakBrailleDots: $speakBrailleDots,
				characterEcho: $characterEcho,
				speechRatePercent: $speechRatePercent,
				speechVolumePercent: $speechVolumePercent,
				selectedVoiceId: $selectedVoiceId,
				customMolePlayModeRawValue: $customMolePlayModeRawValue,
				customIndividualMoleIDs: $customIndividualMoleIDs,
				customInvasionMoleIDs: $customInvasionMoleIDs
			)
		}
		.sheet(
			isPresented: $isShowingHowToPlay,
			onDismiss: {
				guard shouldRestoreHowToPlayFocus else { return }
				shouldRestoreHowToPlayFocus = false
				viewModel.returnFocusToHowToPlay()
			}
		) {
			HowToPlayView(
				onDismissRequest: {
					shouldRestoreHowToPlayFocus = true
				}
			)
		}
		.fullScreenCover(isPresented: $isShowingCashOut, onDismiss: viewModel.cancelCashOut) {
			CashOutView(
				totalTickets: viewModel.totalAccruedTickets,
				prizes: viewModel.cashOutPrizes,
					showKeepWhacking: cashOutOrigin == .roundResults,
					claimPrize: { prizeID in
						let origin = cashOutOrigin
						isShowingCashOut = false
						viewModel.claimPrize(prizeID)
						switch origin {
						case .home:
							viewModel.returnFocusToCashIn()
						case .roundResults:
							viewModel.returnFocusToHomeHeading()
						}
					},
				keepWhacking: {
					isShowingCashOut = false
					viewModel.cancelCashOut()
				},
					returnHome: {
						let origin = cashOutOrigin
						isShowingCashOut = false
						viewModel.returnHomeFromCashOut()
						switch origin {
						case .home:
							viewModel.returnFocusToCashIn()
						case .roundResults:
							viewModel.returnFocusToHomeHeading()
						}
					}
			)
		}
		.onChange(of: viewModel.phase, initial: true) { _, newPhase in
			handlePhaseChange(newPhase)
		}
		.onChange(of: selectedVoiceId) { applySpeechSettings() }
		.onChange(of: speechRatePercent) { applySpeechSettings() }
		.onChange(of: speechVolumePercent) { applySpeechSettings() }
		.onChange(of: timerMusicEnabled) { applyAudioSettings() }
		.onChange(of: gameAudioModeRawValue) { applyAudioSettings() }
		.onAppear {
			applySpeechSettings()
			applyAudioSettings()
			SpeechEngine.shared.prewarm()
			GameAudioEngine.shared.prewarmForHomeScreen()
		}
	}

	private var difficulty: Difficulty {
		Difficulty(rawValue: difficultyRawValue) ?? .normal
	}

	private var viewIdentity: String {
		switch viewModel.phase {
		case .home:
			return "home"
		case .gameplay:
			return "gameplay"
		case .roundResults:
			return "roundResults"
		}
	}

	private var configuredInputMode: InputMode {
		InputMode(rawValue: inputModeRawValue) ?? .qwerty
	}

	private var effectiveInputMode: InputMode {
		configuredInputMode
	}

	private var effectiveModeId: String {
		BrailleRegistry.sanitizedModeId(modeId, for: effectiveInputMode)
	}

	private var customMolePlayMode: CustomMolePlayMode {
		CustomMolePlayMode(rawValue: customMolePlayModeRawValue) ?? .individual
	}

	private var gameAudioMode: GameAudioMode {
		GameAudioMode(rawValue: gameAudioModeRawValue) ?? .original
	}

	private var selectedCustomMoleIDs: [String] {
		let storageValue = customMolePlayMode == .individual ? customIndividualMoleIDs : customInvasionMoleIDs
		return storageValue
			.split(separator: ",")
			.map(String.init)
			.filter { !$0.isEmpty }
	}

	private var difficultyBinding: Binding<Difficulty> {
		Binding(
			get: { difficulty },
			set: { difficultyRawValue = $0.rawValue }
		)
	}

	private var inputModeBinding: Binding<InputMode> {
		Binding(
			get: { configuredInputMode },
			set: { inputModeRawValue = $0.rawValue }
		)
	}

	private func applySpeechSettings() {
		SpeechEngine.shared.configure(
			voice: selectedVoiceId.isEmpty ? nil : AVSpeechSynthesisVoice(identifier: selectedVoiceId),
			rate: speechRateForPercent(speechRatePercent),
			volume: speechVolumeForPercent(speechVolumePercent)
		)
	}

	private func applyAudioSettings() {
		GameAudioEngine.shared.configure(
			timerMusicEnabled: timerMusicEnabled && difficulty != .training,
			gameAudioMode: gameAudioMode
		)
	}

	private func startRound() {
		pendingRoundStartID = UUID()
		applySpeechSettings()
		modeId = effectiveModeId
		let options = GameLoop.Options(
			modeId: effectiveModeId,
			durationSeconds: difficulty.isTimed ? roundDurationSeconds : 30,
			inputMode: effectiveInputMode,
			difficulty: difficulty,
			speakBrailleDots: speakBrailleDots,
			characterEcho: characterEcho,
			timerMusicEnabled: timerMusicEnabled,
			spatialMoleMappingEnabled: spatialMoleMappingEnabled,
			customMolePlayMode: customMolePlayMode,
			customMoleIDs: selectedCustomMoleIDs,
			trainingIntroKind: .standard
		)

		startRound(with: options)
	}

	private func startMoleRecon(items: [BrailleItem], context: MoleReconTrainingContext) {
		guard !items.isEmpty else { return }

		pendingRoundStartID = UUID()
		applySpeechSettings()
		lastMoleReconContext = context

		let options = GameLoop.Options(
			modeId: "moleRecon",
			durationSeconds: 30,
			inputMode: effectiveInputMode,
			difficulty: .training,
			speakBrailleDots: speakBrailleDots,
			characterEcho: characterEcho,
			timerMusicEnabled: false,
			spatialMoleMappingEnabled: false,
			customMolePlayMode: .individual,
			customMoleIDs: items.map(\.id),
			trainingIntroKind: context.selectedMode == .grudgeMatch ? .grudgeMatch : .moleRecon
		)

		startRound(with: options)
	}

	private func keepWhackingFromResults() {
		guard viewModel.lastRoundResult?.isTraining == true else {
			startRound()
			return
		}

		guard let lastTrainingOptions else {
			startRound()
			return
		}

		applySpeechSettings()
		startRound(with: options(lastTrainingOptions, speakBrailleDots: speakBrailleDots))
	}

	private func options(_ options: GameLoop.Options, speakBrailleDots: Bool) -> GameLoop.Options {
		GameLoop.Options(
			modeId: options.modeId,
			durationSeconds: options.durationSeconds,
			inputMode: options.inputMode,
			difficulty: options.difficulty,
			speakBrailleDots: speakBrailleDots,
			characterEcho: options.characterEcho,
			timerMusicEnabled: options.timerMusicEnabled,
			spatialMoleMappingEnabled: options.spatialMoleMappingEnabled,
			customMolePlayMode: options.customMolePlayMode,
			customMoleIDs: options.customMoleIDs,
			trainingIntroKind: options.trainingIntroKind
		)
	}

	private func startRound(with options: GameLoop.Options) {
		let startID = UUID()
		pendingRoundStartID = startID
		if options.difficulty == .training {
			lastTrainingOptions = options
		} else {
			lastTrainingOptions = nil
			lastMoleReconContext = nil
		}
		viewModel.startRound(options: options)
		applyAudioSettings()
		SpeechEngine.shared.prewarm()
		GameAudioEngine.shared.prewarm {
			viewModel.gameLoop.prepareSpeechCache(options: options) {
				beginPreparedRound(startID: startID, options: options)
			}
		}
	}

	private func returnHomeFromResults() {
		viewModel.returnHomeFromResults()
		lastTrainingOptions = nil
		lastMoleReconContext = nil
		DispatchQueue.main.async {
			viewModel.returnFocusToHomeHeading()
		}
	}

	private func cashInTickets() {
		pendingRoundStartID = UUID()
		cashOutOrigin = .roundResults
		dismissTextInputSystem()
		SpeechEngine.shared.cancel()
		GameAudioEngine.shared.stopRound()
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
			viewModel.prepareCashOut()
			isShowingCashOut = true
		}
	}

	private func openPrizeCounter() {
		pendingRoundStartID = UUID()
		cashOutOrigin = .home
		viewModel.prepareCashOut()
		isShowingCashOut = true
	}

	private func handlePhaseChange(_ phase: GameViewModel.Phase) {
		switch phase {
		case .home:
			pendingRoundStartID = UUID()
			break
		case .gameplay:
			break
		case .roundResults:
			pendingRoundStartID = UUID()
			dismissTextInputSystem()
			SpeechEngine.shared.cancel()
			GameAudioEngine.shared.stopRound()
			if viewModel.lastRoundResult?.isTraining == true {
				GameAudioEngine.shared.playTrainingEndCue()
			} else {
				GameAudioEngine.shared.playEndCue()
			}
		}
	}

	private func dismissTextInputSystem() {
		NotificationCenter.default.post(name: .dismissGameplayInput, object: nil)
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
		for scene in UIApplication.shared.connectedScenes {
			guard let windowScene = scene as? UIWindowScene else { continue }
			for window in windowScene.windows {
				window.endEditing(true)
			}
		}
	}

	private func beginPreparedRound(startID: UUID, options: GameLoop.Options) {
		guard pendingRoundStartID == startID else { return }

		let isInvasionMode = options.modeId == "grade1MoleInvasion"
			|| options.modeId == "grade2MoleInvasion"
			|| (options.modeId == "customMoles" && options.customMolePlayMode == .invasion)
		let introText = isInvasionMode
			? (invasionIntroPhrases.randomElement() ?? "Incoming moles!")
			: "Ready?"
		let trainingIntroText = trainingIntroPhrases(for: options.trainingIntroKind).randomElement() ?? "Ready for Training?"
		let announcementText = options.difficulty == .training ? trainingIntroText : introText
		let focusHandoffDelayMs = options.inputMode.usesBufferedTextEntry ? 600 : 300
		let focusSettleDelayMs: Int
		switch options.inputMode {
		case .brailleText, .brailleDisplayInput:
			focusSettleDelayMs = 1_250
		case .oneHandedBrailleInput:
			focusSettleDelayMs = 1_650
		case .qwerty, .perkins:
			focusSettleDelayMs = 900
		}
		let postSpeechBeatMs = options.difficulty == .training ? 850 : 300
		let announcementDelayMs = options.difficulty == .training
			? max(focusSettleDelayMs, 1_850)
			: focusSettleDelayMs

		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(focusHandoffDelayMs)) {
			guard pendingRoundStartID == startID else { return }
			if options.difficulty == .training {
				GameAudioEngine.shared.playTrainingOpeningCue()
			} else {
				GameAudioEngine.shared.playOpeningCue(playEverythingIntro: isInvasionMode)
			}

			DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(announcementDelayMs)) {
				guard pendingRoundStartID == startID else { return }
				let speechDurationMs = SpeechEngine.shared.estimatedDurationMs(for: announcementText)

				SpeechEngine.shared.prepareCachedSpeech(for: [announcementText]) {
					guard pendingRoundStartID == startID else { return }
					playPreparedSpeech(announcementText)
					let startDelayMs = min(3_000, speechDurationMs + postSpeechBeatMs)

					DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(startDelayMs)) {
						guard pendingRoundStartID == startID else { return }
						viewModel.beginRound(options: options)
					}
				}
			}
		}
	}

	private func playPreparedSpeech(_ text: String) {
		if let data = SpeechEngine.shared.cachedSpeechData(for: text) {
			GameAudioEngine.shared.playSpeechData(data)
			return
		}

		SpeechEngine.shared.speak(text, interrupt: true)
	}

	private func trainingIntroPhrases(for kind: GameLoop.TrainingIntroKind) -> [String] {
		switch kind {
		case .standard:
			return [
				"Training Mode",
				"Ready for Training?",
				"Warm up those dots!"
			]
		case .moleRecon:
			return [
				"Mole Recon Training",
				"Ready for Recon?",
				"Target practice begins!"
			]
		case .grudgeMatch:
			return [
				"Grudge Match!",
				"Show 'em What's For!",
				"Time for Payback Practice!"
			]
		}
	}

	private func speechRateForPercent(_ percent: Int) -> Float {
		let clamped = min(max(percent, 1), 100)
		let progress = Float(clamped - 1) / 99.0
		return AVSpeechUtteranceMinimumSpeechRate + ((AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * progress)
	}

	private func speechVolumeForPercent(_ percent: Int) -> Float {
		let clamped = min(max(percent, 5), 100)
		return Float(clamped) / 100.0
	}
}

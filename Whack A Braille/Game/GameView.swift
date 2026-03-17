import AVFoundation
import SwiftUI

struct GameView: View {

	@StateObject private var viewModel = GameViewModel()

	@AppStorage("whackABraille.modeId") private var modeId = "grade1Letters"
	@AppStorage("whackABraille.difficulty") private var difficultyRawValue = Difficulty.normal.rawValue
	@AppStorage("whackABraille.roundDurationSeconds") private var roundDurationSeconds = 30
	@AppStorage("whackABraille.inputMode") private var inputModeRawValue = InputMode.qwerty.rawValue
	@AppStorage("whackABraille.audioMode") private var audioMode = "original"
	@AppStorage("whackABraille.timerMusicEnabled") private var timerMusicEnabled = true
	@AppStorage("whackABraille.spatialMoleMappingEnabled") private var spatialMoleMappingEnabled = true
	@AppStorage("whackABraille.speakBrailleDots") private var speakBrailleDots = false
	@AppStorage("whackABraille.characterEcho") private var characterEcho = false
	@AppStorage("whackABraille.speechRatePercent") private var speechRatePercent = 35
	@AppStorage("whackABraille.selectedVoiceId") private var selectedVoiceId = ""

	@State private var isShowingSettings = false
	@State private var isPreparingRound = false

	var body: some View {
		Group {
			switch viewModel.phase {
			case .home:
				HomeView(
					prizeShelfItems: viewModel.prizeShelfItems,
					homeNotice: viewModel.homeNotice,
					openSettings: { isShowingSettings = true },
					startGame: startRound,
					clearPrizeShelf: viewModel.clearPrizeShelf
				)
			case .gameplay:
				GameplayView(
					viewModel: viewModel,
					inputMode: effectiveInputMode,
					isPreparingRound: isPreparingRound
				)
			case .roundResults:
				RoundResultsView(
					result: viewModel.lastRoundResult,
					totalTickets: viewModel.totalAccruedTickets,
					keepWhacking: startRound,
					cashInTickets: viewModel.cashInTickets
				)
			}
		}
		.sheet(isPresented: $isShowingSettings) {
			GameSettingsSheet(
				modeId: $modeId,
				difficulty: difficultyBinding,
				roundDurationSeconds: $roundDurationSeconds,
				inputMode: inputModeBinding,
				audioMode: $audioMode,
				timerMusicEnabled: $timerMusicEnabled,
				spatialMoleMappingEnabled: $spatialMoleMappingEnabled,
				speakBrailleDots: $speakBrailleDots,
				characterEcho: $characterEcho,
				speechRatePercent: $speechRatePercent,
				selectedVoiceId: $selectedVoiceId
			)
		}
		.onChange(of: selectedVoiceId) { applySpeechSettings() }
		.onChange(of: speechRatePercent) { applySpeechSettings() }
	}

	private var difficulty: Difficulty {
		Difficulty(rawValue: difficultyRawValue) ?? .normal
	}

	private var configuredInputMode: InputMode {
		InputMode(rawValue: inputModeRawValue) ?? .qwerty
	}

	private var effectiveInputMode: InputMode {
		modeId == "everything" ? .perkins : configuredInputMode
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
			rate: speechRateForPercent(speechRatePercent)
		)
	}

	private func startRound() {
		guard !isPreparingRound else { return }
		applySpeechSettings()
		let options = GameLoop.Options(
			modeId: modeId,
			durationSeconds: difficulty.isTimed ? roundDurationSeconds : 30,
			inputMode: effectiveInputMode,
			difficulty: difficulty,
			speakBrailleDots: speakBrailleDots,
			characterEcho: characterEcho,
			timerMusicEnabled: timerMusicEnabled,
			spatialMoleMappingEnabled: spatialMoleMappingEnabled,
			audioMode: audioMode
		)

		isPreparingRound = true
		viewModel.startRound(options: options)
		GameAudioEngine.shared.prepareForGameplay(
			mode: audioMode,
			timerMusicEnabled: timerMusicEnabled && difficulty != .training
		) {
			SpeechEngine.shared.prewarm()

			DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
				GameAudioEngine.shared.playOpeningCue(playEverythingIntro: modeId == "everything")
				_ = SpeechEngine.shared.speak(modeId == "everything" ? "Incoming Mole Invasion!" : "Ready?", interrupt: true)
			}

			DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
				isPreparingRound = false
				viewModel.beginRound(options: options)
			}
		}
	}

	private func speechRateForPercent(_ percent: Int) -> Float {
		let clamped = min(max(percent, 1), 100)
		let progress = Float(clamped - 1) / 99.0
		return AVSpeechUtteranceMinimumSpeechRate + ((AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * progress)
	}
}

import AVFoundation
import SwiftUI
import UIKit

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
	@State private var pendingRoundStartID = UUID()

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
					exitGame: viewModel.exitRoundToResults
				)
			case .roundResults:
				RoundResultsView(
					result: viewModel.lastRoundResult,
					totalTickets: viewModel.totalAccruedTickets,
					keepWhacking: startRound,
					cashInTickets: cashInTickets,
					onAppearAction: handleResultsAppear
				)
			case .cashOut:
				CashOutView(
					totalTickets: viewModel.totalAccruedTickets,
					prizes: viewModel.cashOutPrizes,
					claimPrize: viewModel.claimPrize,
					keepWhacking: viewModel.cancelCashOut
				)
			}
		}
		.id(viewIdentity)
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

	private var viewIdentity: String {
		switch viewModel.phase {
		case .home:
			return "home"
		case .gameplay:
			return "gameplay"
		case .roundResults:
			return "roundResults"
		case .cashOut:
			return "cashOut"
		}
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
		pendingRoundStartID = UUID()
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

		let startID = UUID()
		pendingRoundStartID = startID
		viewModel.startRound(options: options)
		GameAudioEngine.shared.configure(
			mode: audioMode,
			timerMusicEnabled: timerMusicEnabled && difficulty != .training
		)
		GameAudioEngine.shared.prewarm()
		SpeechEngine.shared.prewarm()

		waitForRoundReadiness(startID: startID, options: options, startedAt: Date.timeIntervalSinceReferenceDate)
	}

	private func cashInTickets() {
		pendingRoundStartID = UUID()
		NotificationCenter.default.post(name: .dismissGameplayInput, object: nil)
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
		SpeechEngine.shared.cancel()
		GameAudioEngine.shared.stopRound()
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			viewModel.cashInTickets()
		}
	}

	private func handleResultsAppear() {
		pendingRoundStartID = UUID()
		NotificationCenter.default.post(name: .dismissGameplayInput, object: nil)
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
		GameAudioEngine.shared.playEndCue()
	}

	private func waitForRoundReadiness(startID: UUID, options: GameLoop.Options, startedAt: TimeInterval) {
		guard pendingRoundStartID == startID else { return }

		let elapsed = Date.timeIntervalSinceReferenceDate - startedAt
		let isReady = GameAudioEngine.shared.isReadyForGameplay || elapsed >= 2.5

		guard isReady else {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
				waitForRoundReadiness(startID: startID, options: options, startedAt: startedAt)
			}
			return
		}

		let introText = modeId == "everything" ? "Incoming Mole Invasion!" : "Ready?"
		GameAudioEngine.shared.playOpeningCue(playEverythingIntro: modeId == "everything")
		let speechDurationMs = SpeechEngine.shared.speak(introText, interrupt: true)
		let startDelayMs = max(700, min(2_400, speechDurationMs + 180))

		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(startDelayMs)) {
			guard pendingRoundStartID == startID else { return }
			viewModel.beginRound(options: options)
		}
	}

	private func speechRateForPercent(_ percent: Int) -> Float {
		let clamped = min(max(percent, 1), 100)
		let progress = Float(clamped - 1) / 99.0
		return AVSpeechUtteranceMinimumSpeechRate + ((AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * progress)
	}
}

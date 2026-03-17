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
	@State private var isShowingSettings: Bool = false

	var body: some View {
		Group {
			switch viewModel.phase {
			case .home:
				HomeView(
					totalTickets: viewModel.totalAccruedTickets,
					prizeShelfSummary: viewModel.prizeShelfSummary,
					homeNotice: viewModel.homeNotice,
					openSettings: { isShowingSettings = true },
					startGame: startRound
				)
			case .gameplay:
				GameplayView(
					viewModel: viewModel,
					inputMode: inputMode,
					brailleSubmitMode: brailleSubmitMode,
					stopRound: viewModel.stopRound
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
				difficulty: $difficulty,
				roundDurationSeconds: $roundDurationSeconds,
				inputMode: $inputMode,
				brailleSubmitMode: $brailleSubmitMode,
				speechRate: $speechRate,
				selectedVoiceId: $selectedVoiceId
			)
		}
		.onAppear {
			applySpeechSettings()
		}
		.onChange(of: selectedVoiceId) {
			applySpeechSettings()
		}
		.onChange(of: speechRate) {
			applySpeechSettings()
		}
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

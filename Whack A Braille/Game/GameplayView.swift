import SwiftUI

struct GameplayView: View {

	@ObservedObject var viewModel: GameViewModel
	let inputMode: InputMode
	let exitGame: () -> Void

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				VStack(alignment: .leading, spacing: 14) {
					Text("Whack the Braille!")
						.font(.system(size: 34, weight: .heavy, design: .rounded))
						.foregroundStyle(AppTheme.heading)
						.accessibilityAddTraits(.isHeader)

					if !viewModel.lastRoundWasTraining {
						Text("Score: \(viewModel.score)")
							.font(.headline)
							.padding(.horizontal, 14)
							.padding(.vertical, 10)
							.background(
								LinearGradient(
									colors: [AppTheme.scoreStart, AppTheme.scoreEnd],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.foregroundStyle(AppTheme.primaryButtonText)
							.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
							.accessibilityLabel("Score \(viewModel.score)")
					}
				}
				.appCard()

				VStack(alignment: .leading, spacing: 16) {
					HStack(spacing: 12) {
						ForEach(0..<5, id: \.self) { lane in
							RoundedRectangle(cornerRadius: 18)
								.fill(
									viewModel.activeLane == lane
										? LinearGradient(
											colors: [AppTheme.scoreStart, AppTheme.scoreEnd],
											startPoint: .topLeading,
											endPoint: .bottomTrailing
										)
										: LinearGradient(
											colors: [AppTheme.heading.opacity(0.45), AppTheme.focus.opacity(0.18)],
											startPoint: .topLeading,
											endPoint: .bottomTrailing
										)
								)
								.frame(maxWidth: .infinity, minHeight: 80)
								.accessibilityHidden(true)
						}
					}
					.accessibilityHidden(true)

					VStack(alignment: .leading, spacing: 8) {
						Text("Braille Entry")
							.font(.headline)

						BrailleTextInputSinkView(
							gameLoop: viewModel.gameLoop,
							inputMode: inputMode,
							isEnabled: viewModel.isRunning,
							autoFocus: viewModel.isRunning,
							resetToken: viewModel.inputResetToken
						)
						.frame(height: 48)
					}

					Button("Exit Game", action: exitGame)
						.buttonStyle(SecondaryGameButton())
				}
				.appCard()
			}
			.padding(24)
		}
		.appBackground()
	}
}

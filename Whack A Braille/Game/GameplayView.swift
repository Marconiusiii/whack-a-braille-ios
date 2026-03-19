import SwiftUI

struct GameplayView: View {

	@ObservedObject var viewModel: GameViewModel
	let inputMode: InputMode
	let exitGame: () -> Void
	@Environment(\.colorScheme) private var colorScheme

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
					gameBoard
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

	private var gameBoard: some View {
		HStack(alignment: .bottom, spacing: 12) {
			ForEach(0..<5, id: \.self) { lane in
				MoleLaneView(
					label: viewModel.activeLane == lane ? viewModel.activeTargetLabel : nil,
					isActive: viewModel.activeLane == lane,
					feedbackKind: viewModel.feedbackLane == lane ? viewModel.feedbackKind : nil
				)
			}
		}
		.padding(16)
		.background(boardBackground)
		.clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 26, style: .continuous)
				.stroke(boardBorder, lineWidth: 1)
		)
		.shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
	}

	private var boardBackground: some ShapeStyle {
		LinearGradient(
			colors: colorScheme == .dark
				? [AppTheme.boardSurfaceDark, AppTheme.darkBackgroundBottom]
				: [AppTheme.boardSurfaceLight, AppTheme.lightBackgroundBottom],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	private var boardBorder: Color {
		AppTheme.focus.opacity(0.22)
	}
}

private struct MoleLaneView: View {

	let label: String?
	let isActive: Bool
	let feedbackKind: GameLoop.FeedbackKind?
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		ZStack(alignment: .bottom) {
			RoundedRectangle(cornerRadius: 22, style: .continuous)
				.fill(laneWellGradient)
				.overlay(alignment: .top) {
					RoundedRectangle(cornerRadius: 22, style: .continuous)
						.fill(laneGloss)
						.frame(height: 24)
				}

			RoundedRectangle(cornerRadius: 18, style: .continuous)
				.fill(moleGradient)
				.overlay {
					Text(label ?? "")
						.font(.system(size: moleFontSize, weight: .heavy, design: .rounded))
						.foregroundStyle(labelColor)
						.multilineTextAlignment(.center)
						.minimumScaleFactor(0.55)
						.lineLimit(2)
						.padding(.horizontal, 8)
						.shadow(color: Color.black.opacity(isActive ? 0.55 : 0), radius: 10, x: 0, y: 2)
						.scaleEffect(isActive ? 1 : 0.92)
						.offset(y: isActive ? 0 : 4)
						.opacity(isActive ? 1 : 0)
						.animation(.easeOut(duration: 0.11), value: isActive)
				}
				.overlay {
					if feedbackKind == .hit {
						RoundedRectangle(cornerRadius: 18, style: .continuous)
							.fill(
								RadialGradient(
									colors: [AppTheme.moleWarmStart.opacity(0.95), AppTheme.moleWarmEnd.opacity(0.78)],
									center: .topLeading,
									startRadius: 8,
									endRadius: 90
								)
							)
							.blendMode(.screen)
					} else if isActive {
						RoundedRectangle(cornerRadius: 18, style: .continuous)
							.fill(
								RadialGradient(
									colors: [Color.white.opacity(0.28), .clear],
									center: .topLeading,
									startRadius: 8,
									endRadius: 80
								)
							)
					}
				}
				.overlay(
					RoundedRectangle(cornerRadius: 18, style: .continuous)
						.stroke(borderColor, lineWidth: feedbackKind == .hit ? 2 : 1)
				)
				.frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
				.offset(y: isActive ? 0 : 22)
				.scaleEffect(scale)
				.opacity(isActive ? 1 : 0.16)
				.saturation(isActive ? 1 : 0.9)
				.shadow(color: Color.black.opacity(isActive ? 0.5 : 0.22), radius: isActive ? 18 : 8, x: 0, y: isActive ? 10 : 5)
				.animation(.interactiveSpring(response: 0.2, dampingFraction: 0.78), value: isActive)
				.animation(.easeOut(duration: 0.17), value: feedbackKind == .hit)
				.animation(.easeOut(duration: 0.14), value: feedbackKind == .miss)
				.padding(.horizontal, 2)
		}
		.frame(maxWidth: .infinity, minHeight: 146, maxHeight: 146, alignment: .bottom)
	}

	private var laneWellGradient: some ShapeStyle {
		LinearGradient(
			colors: colorScheme == .dark
				? [AppTheme.boardLipDark.opacity(0.7), AppTheme.boardSurfaceDark]
				: [AppTheme.boardLipLight, AppTheme.boardSurfaceLight],
			startPoint: .top,
			endPoint: .bottom
		)
	}

	private var laneGloss: some ShapeStyle {
		LinearGradient(
			colors: [Color.white.opacity(0.09), .clear],
			startPoint: .top,
			endPoint: .bottom
		)
	}

	private var moleGradient: some ShapeStyle {
		LinearGradient(
			colors: feedbackKind == .hit
				? [AppTheme.moleWarmStart, AppTheme.moleWarmEnd]
				: isActive
				? [AppTheme.moleWarmStart, AppTheme.moleWarmEnd]
				: [AppTheme.moleCoolStart, AppTheme.moleCoolEnd],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	private var moleFontSize: CGFloat {
		guard let label else { return 30 }
		return label.contains(" ") || label.contains("+") || label.count > 3 ? 22 : 30
	}

	private var labelColor: Color {
		if feedbackKind == .miss {
			return AppTheme.missMuted
		}
		return isActive ? AppTheme.darkText : AppTheme.darkText.opacity(0)
	}

	private var borderColor: Color {
		if feedbackKind == .hit {
			return AppTheme.focus.opacity(0.52)
		}
		if feedbackKind == .miss {
			return AppTheme.missMuted.opacity(0.22)
		}
		return AppTheme.focus.opacity(isActive ? 0.28 : 0.08)
	}

	private var scale: CGFloat {
		if feedbackKind == .hit {
			return 0.92
		}
		return isActive ? 1 : 0.98
	}
}

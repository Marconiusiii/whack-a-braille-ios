import SwiftUI

enum AppTheme {

	static let darkBackgroundTop = Color(red: 11 / 255, green: 16 / 255, blue: 32 / 255)
	static let darkBackgroundBottom = Color(red: 5 / 255, green: 8 / 255, blue: 20 / 255)
	static let darkCard = Color(red: 15 / 255, green: 23 / 255, blue: 48 / 255)
	static let darkCardOverlay = Color.white.opacity(0.035)
	static let darkText = Color(red: 245 / 255, green: 247 / 255, blue: 255 / 255)
	static let darkSecondaryText = Color(red: 189 / 255, green: 198 / 255, blue: 219 / 255)

	static let lightBackgroundTop = Color(red: 250 / 255, green: 244 / 255, blue: 255 / 255)
	static let lightBackgroundBottom = Color(red: 238 / 255, green: 247 / 255, blue: 255 / 255)
	static let lightCard = Color.white.opacity(0.92)
	static let lightCardOverlay = Color(red: 123 / 255, green: 223 / 255, blue: 242 / 255).opacity(0.06)
	static let lightText = Color(red: 19 / 255, green: 30 / 255, blue: 57 / 255)
	static let lightSecondaryText = Color(red: 69 / 255, green: 82 / 255, blue: 111 / 255)

	static let title = Color(red: 1.0, green: 230 / 255, blue: 109 / 255)
	static let heading = Color(red: 123 / 255, green: 223 / 255, blue: 242 / 255)
	static let shelfAccent = Color(red: 205 / 255, green: 180 / 255, blue: 255 / 255)
	static let primaryButton = Color(red: 1.0, green: 111 / 255, blue: 145 / 255)
	static let primaryButtonPressed = Color(red: 1.0, green: 143 / 255, blue: 171 / 255)
	static let primaryButtonText = Color(red: 11 / 255, green: 16 / 255, blue: 32 / 255)
	static let focus = Color(red: 123 / 255, green: 223 / 255, blue: 242 / 255)
	static let scoreStart = Color(red: 1.0, green: 190 / 255, blue: 11 / 255)
	static let scoreEnd = Color(red: 251 / 255, green: 86 / 255, blue: 7 / 255)
	static let lightBorder = Color(red: 123 / 255, green: 223 / 255, blue: 242 / 255).opacity(0.26)
	static let darkBorder = Color(red: 123 / 255, green: 223 / 255, blue: 242 / 255).opacity(0.22)
	static let moleCoolStart = Color(red: 108 / 255, green: 99 / 255, blue: 1.0)
	static let moleCoolEnd = Color(red: 58 / 255, green: 45 / 255, blue: 191 / 255)
	static let moleWarmStart = Color(red: 1.0, green: 190 / 255, blue: 11 / 255)
	static let moleWarmEnd = Color(red: 251 / 255, green: 86 / 255, blue: 7 / 255)
	static let boardSurfaceDark = Color(red: 9 / 255, green: 13 / 255, blue: 28 / 255)
	static let boardSurfaceLight = Color(red: 230 / 255, green: 238 / 255, blue: 1.0)
	static let boardLipDark = Color.white.opacity(0.06)
	static let boardLipLight = Color.white.opacity(0.78)
	static let settingsRowLight = Color.white.opacity(0.9)
	static let settingsRowDark = Color(red: 15 / 255, green: 23 / 255, blue: 48 / 255).opacity(0.96)
	static let settingsSectionHeader = Color(red: 205 / 255, green: 180 / 255, blue: 255 / 255)
	static let prizeShelfTop = Color(red: 26 / 255, green: 32 / 255, blue: 64 / 255)
	static let prizeShelfBottom = Color(red: 11 / 255, green: 16 / 255, blue: 32 / 255)
	static let plaqueDarkStart = Color(red: 111 / 255, green: 78 / 255, blue: 0)
	static let plaqueDarkMid = Color(red: 184 / 255, green: 134 / 255, blue: 11 / 255)
	static let plaqueLightMid = Color(red: 224 / 255, green: 184 / 255, blue: 74 / 255)
	static let plaqueText = Color(red: 1.0, green: 246 / 255, blue: 213 / 255)
	static let missMuted = Color(red: 160 / 255, green: 160 / 255, blue: 160 / 255)
	static let summaryRowLight = Color.white.opacity(0.88)
	static let summaryRowDark = Color(red: 9 / 255, green: 13 / 255, blue: 28 / 255).opacity(0.92)
	static let gameplayInputLight = Color.white.opacity(0.82)
	static let gameplayInputDark = Color(red: 9 / 255, green: 13 / 255, blue: 28 / 255).opacity(0.96)
}

struct AppBackground: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	func body(content: Content) -> some View {
		ZStack {
			LinearGradient(
				colors: colorScheme == .dark
					? [AppTheme.darkBackgroundTop, AppTheme.darkBackgroundBottom]
					: [AppTheme.lightBackgroundTop, AppTheme.lightBackgroundBottom],
				startPoint: .top,
				endPoint: .bottom
			)
			.ignoresSafeArea()

			content
		}
	}
}

struct AppCard: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	func body(content: Content) -> some View {
		content
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				ZStack {
					(colorScheme == .dark ? AppTheme.darkCard : AppTheme.lightCard)
					LinearGradient(
						colors: colorScheme == .dark
							? [AppTheme.darkCardOverlay, .clear]
							: [AppTheme.lightCardOverlay, .clear],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				}
			)
			.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 22, style: .continuous)
					.stroke(colorScheme == .dark ? AppTheme.darkBorder : AppTheme.lightBorder, lineWidth: 1)
			)
			.shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 18, x: 0, y: 10)
	}
}

struct AppActionCard: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	func body(content: Content) -> some View {
		content
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				ZStack {
					(colorScheme == .dark ? AppTheme.darkCard : AppTheme.lightCard)
					LinearGradient(
						colors: colorScheme == .dark
							? [AppTheme.darkCardOverlay, .clear]
							: [AppTheme.lightCardOverlay, .clear],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				}
			)
			.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 22, style: .continuous)
					.stroke(colorScheme == .dark ? AppTheme.darkBorder : AppTheme.lightBorder, lineWidth: 1)
			)
			.shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 18, x: 0, y: 10)
	}
}

struct PrimaryGameButton: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.headline)
			.multilineTextAlignment(.center)
			.lineLimit(nil)
			.fixedSize(horizontal: false, vertical: true)
			.frame(maxWidth: .infinity)
			.frame(minHeight: 52)
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
			.background(configuration.isPressed ? AppTheme.primaryButtonPressed : AppTheme.primaryButton)
			.foregroundStyle(AppTheme.primaryButtonText)
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(AppTheme.primaryButtonText.opacity(0.08), lineWidth: 1)
			)
			.shadow(color: AppTheme.primaryButton.opacity(configuration.isPressed ? 0.18 : 0.3), radius: configuration.isPressed ? 8 : 14, x: 0, y: configuration.isPressed ? 4 : 8)
			.scaleEffect(configuration.isPressed ? 0.98 : 1.0)
			.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
	}
}

struct SecondaryGameButton: ButtonStyle {
	@Environment(\.colorScheme) private var colorScheme

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.headline)
			.multilineTextAlignment(.center)
			.lineLimit(nil)
			.fixedSize(horizontal: false, vertical: true)
			.frame(maxWidth: .infinity)
			.frame(minHeight: 52)
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill((colorScheme == .dark ? AppTheme.darkCard : Color.white).opacity(configuration.isPressed ? 0.82 : 0.96))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(AppTheme.focus.opacity(0.45), lineWidth: 2)
			)
			.foregroundStyle(colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText)
			.shadow(color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.06), radius: 10, x: 0, y: 6)
			.scaleEffect(configuration.isPressed ? 0.98 : 1.0)
			.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
	}
}

struct FullRegionPrimaryGameButton: ButtonStyle {
	let visibleMinHeight: CGFloat
	let horizontalInset: CGFloat
	let verticalInset: CGFloat

	init(visibleMinHeight: CGFloat = 52, horizontalInset: CGFloat = 20, verticalInset: CGFloat = 12) {
		self.visibleMinHeight = visibleMinHeight
		self.horizontalInset = horizontalInset
		self.verticalInset = verticalInset
	}

	func makeBody(configuration: Configuration) -> some View {
		ZStack {
			configuration.label
				.font(.headline)
				.multilineTextAlignment(.center)
				.lineLimit(nil)
				.fixedSize(horizontal: false, vertical: true)
				.frame(maxWidth: .infinity)
				.frame(minHeight: visibleMinHeight)
				.padding(.horizontal, 16)
				.padding(.vertical, 8)
				.background(configuration.isPressed ? AppTheme.primaryButtonPressed : AppTheme.primaryButton)
				.foregroundStyle(AppTheme.primaryButtonText)
				.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
				.overlay(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.stroke(AppTheme.primaryButtonText.opacity(0.08), lineWidth: 1)
				)
				.shadow(color: AppTheme.primaryButton.opacity(configuration.isPressed ? 0.18 : 0.3), radius: configuration.isPressed ? 8 : 14, x: 0, y: configuration.isPressed ? 4 : 8)
				.scaleEffect(configuration.isPressed ? 0.98 : 1.0)
				.padding(.horizontal, horizontalInset)
				.padding(.vertical, verticalInset)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.contentShape(Rectangle())
	}
}

struct FullRegionSecondaryGameButton: ButtonStyle {
	@Environment(\.colorScheme) private var colorScheme

	let visibleMinHeight: CGFloat
	let horizontalInset: CGFloat
	let verticalInset: CGFloat

	init(visibleMinHeight: CGFloat = 52, horizontalInset: CGFloat = 12, verticalInset: CGFloat = 12) {
		self.visibleMinHeight = visibleMinHeight
		self.horizontalInset = horizontalInset
		self.verticalInset = verticalInset
	}

	func makeBody(configuration: Configuration) -> some View {
		ZStack {
			configuration.label
				.font(.headline)
				.multilineTextAlignment(.center)
				.lineLimit(nil)
				.fixedSize(horizontal: false, vertical: true)
				.frame(maxWidth: .infinity)
				.frame(minHeight: visibleMinHeight)
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
				.background(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill((colorScheme == .dark ? AppTheme.darkCard : Color.white).opacity(configuration.isPressed ? 0.82 : 0.96))
				)
				.overlay(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.stroke(AppTheme.focus.opacity(0.45), lineWidth: 2)
				)
				.foregroundStyle(colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText)
				.shadow(color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.06), radius: 10, x: 0, y: 6)
				.scaleEffect(configuration.isPressed ? 0.98 : 1.0)
				.padding(.horizontal, horizontalInset)
				.padding(.vertical, verticalInset)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.contentShape(Rectangle())
	}
}

extension View {
	func appBackground() -> some View {
		modifier(AppBackground())
	}

	func appCard() -> some View {
		modifier(AppCard())
	}

	func appActionCard() -> some View {
		modifier(AppActionCard())
	}

	func accessibilityTouchRegion(
		minHeight: CGFloat = 64,
		verticalPadding: CGFloat = 0,
		horizontalPadding: CGFloat = 0,
		alignment: Alignment = .center
	) -> some View {
		padding(.horizontal, horizontalPadding)
			.padding(.vertical, verticalPadding)
			.frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
			.contentShape(Rectangle())
	}

	func accessibilityTouchRegion(
		minHeight: CGFloat = 64,
		topPadding: CGFloat,
		bottomPadding: CGFloat,
		horizontalPadding: CGFloat = 0,
		alignment: Alignment = .center
	) -> some View {
		padding(.horizontal, horizontalPadding)
			.padding(.top, topPadding)
			.padding(.bottom, bottomPadding)
			.frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
			.contentShape(Rectangle())
	}
}

struct SummaryRowCard: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	func body(content: Content) -> some View {
		content
			.padding(.horizontal, 14)
			.padding(.vertical, 12)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(colorScheme == .dark ? AppTheme.summaryRowDark : AppTheme.summaryRowLight)
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(AppTheme.focus.opacity(colorScheme == .dark ? 0.14 : 0.18), lineWidth: 1)
			)
	}
}

struct GameplayInputCard: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	func body(content: Content) -> some View {
		content
			.padding(14)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(colorScheme == .dark ? AppTheme.gameplayInputDark : AppTheme.gameplayInputLight)
			.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.stroke(AppTheme.focus.opacity(0.24), lineWidth: 1.5)
			)
	}
}

extension View {
	func summaryRowCard() -> some View {
		modifier(SummaryRowCard())
	}

	func gameplayInputCard() -> some View {
		modifier(GameplayInputCard())
	}
}

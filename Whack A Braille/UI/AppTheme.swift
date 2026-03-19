import SwiftUI

enum AppTheme {

	static let darkBackgroundTop = Color(red: 11 / 255, green: 16 / 255, blue: 32 / 255)
	static let darkBackgroundBottom = Color(red: 5 / 255, green: 8 / 255, blue: 20 / 255)
	static let darkCard = Color(red: 15 / 255, green: 23 / 255, blue: 48 / 255)
	static let darkText = Color(red: 245 / 255, green: 247 / 255, blue: 255 / 255)
	static let darkSecondaryText = Color(red: 189 / 255, green: 198 / 255, blue: 219 / 255)

	static let lightBackgroundTop = Color(red: 255 / 255, green: 250 / 255, blue: 235 / 255)
	static let lightBackgroundBottom = Color(red: 244 / 255, green: 246 / 255, blue: 255 / 255)
	static let lightCard = Color.white.opacity(0.9)
	static let lightText = Color(red: 19 / 255, green: 30 / 255, blue: 57 / 255)
	static let lightSecondaryText = Color(red: 69 / 255, green: 82 / 255, blue: 111 / 255)

	static let title = Color(red: 1.0, green: 230 / 255, blue: 109 / 255)
	static let heading = Color(red: 123 / 255, green: 223 / 255, blue: 242 / 255)
	static let primaryButton = Color(red: 1.0, green: 111 / 255, blue: 145 / 255)
	static let primaryButtonText = Color(red: 11 / 255, green: 16 / 255, blue: 32 / 255)
	static let focus = Color(red: 123 / 255, green: 223 / 255, blue: 242 / 255)
	static let scoreStart = Color(red: 1.0, green: 190 / 255, blue: 11 / 255)
	static let scoreEnd = Color(red: 251 / 255, green: 86 / 255, blue: 7 / 255)
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
			.background(colorScheme == .dark ? AppTheme.darkCard : AppTheme.lightCard)
			.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 22, style: .continuous)
					.stroke(AppTheme.focus.opacity(colorScheme == .dark ? 0.16 : 0.22), lineWidth: 1)
			)
	}
}

struct PrimaryGameButton: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.headline)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
			.background(configuration.isPressed ? AppTheme.primaryButton.opacity(0.82) : AppTheme.primaryButton)
			.foregroundStyle(AppTheme.primaryButtonText)
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			.scaleEffect(configuration.isPressed ? 0.98 : 1.0)
	}
}

struct SecondaryGameButton: ButtonStyle {
	@Environment(\.colorScheme) private var colorScheme

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.headline)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill((colorScheme == .dark ? AppTheme.darkCard : Color.white).opacity(configuration.isPressed ? 0.78 : 0.94))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(AppTheme.focus.opacity(0.45), lineWidth: 2)
			)
			.foregroundStyle(colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText)
			.scaleEffect(configuration.isPressed ? 0.98 : 1.0)
	}
}

extension View {
	func appBackground() -> some View {
		modifier(AppBackground())
	}

	func appCard() -> some View {
		modifier(AppCard())
	}
}

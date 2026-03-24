import SwiftUI

struct HomeView: View {

	private enum FocusTarget: Hashable {
		case howToPlay
		case clearPrizeShelf
		case emptyShelfMessage
	}

	let totalTickets: Int
	let prizeShelfItems: [String]
	let prizeShelfCount: Int
	let homeNotice: String?
	let howToPlayFocusToken: Int
	let openHowToPlay: () -> Void
	let openPrizeCounter: () -> Void
	let openSettings: () -> Void
	let startGame: () -> Void
	let clearPrizeShelf: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@State private var isPrizeShelfExpanded = false
	@State private var isShowingClearShelfConfirmation = false
	@State private var isShowingEmptyShelfAlert = false
	@AccessibilityFocusState private var focusedElement: FocusTarget?

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				VStack(alignment: .leading, spacing: 12) {
					Text("Whack A Braille")
						.font(.system(.largeTitle, design: .rounded, weight: .heavy))
						.foregroundStyle(AppTheme.title)
						.accessibilityAddTraits(.isHeader)

					Text("Listen sharp, type fast, and send those braille moles scampering before they duck away. Rack up tickets with Braille Screen Input, a keyboard, or your braille display, then cash in for silly prizes.")
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)

					if let homeNotice {
						Text(homeNotice)
							.foregroundStyle(AppTheme.heading)
					}
				}
				.appCard()

				VStack(alignment: .leading, spacing: 12) {
					Button("How to Play", action: openHowToPlay)
						.buttonStyle(SecondaryGameButton())
						.accessibilityFocused($focusedElement, equals: .howToPlay)

					Button(action: openPrizeCounter) {
						HStack(spacing: 12) {
							Text("Cash In Tickets")
							Spacer(minLength: 12)
							Text("\(totalTickets)")
								.font(.subheadline.weight(.bold))
								.foregroundStyle(AppTheme.primaryButtonText)
								.padding(.horizontal, 10)
								.padding(.vertical, 6)
								.background(
									Capsule(style: .continuous)
										.fill(AppTheme.focus)
								)
						}
					}
						.buttonStyle(SecondaryGameButton())
						.accessibilityValue("\(totalTickets) available")
						.accessibilityHint("Opens Prize Counter")

					Button("Game Settings", action: openSettings)
						.buttonStyle(SecondaryGameButton())

					Button("Start Whacking", action: startGame)
						.buttonStyle(PrimaryGameButton())
				}
				.appCard()

				DisclosureGroup(
					isExpanded: $isPrizeShelfExpanded,
					content: {
					VStack(alignment: .leading, spacing: 12) {
						if prizeShelfItems.isEmpty {
							Text("Your shelf is empty. Go bonk some moles and win something shiny!")
								.foregroundStyle(secondaryTextColor)
								.fixedSize(horizontal: false, vertical: true)
								.accessibilityFocused($focusedElement, equals: .emptyShelfMessage)
						} else {
							ForEach(prizeShelfItems, id: \.self) { item in
								Text(item)
									.font(.headline)
									.foregroundStyle(AppTheme.plaqueText)
									.frame(maxWidth: .infinity, alignment: .leading)
									.padding(.horizontal, 14)
									.padding(.vertical, 12)
									.background(plaqueBackground)
									.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
									.overlay(
										RoundedRectangle(cornerRadius: 14, style: .continuous)
											.stroke(Color.white.opacity(0.16), lineWidth: 1)
									)
									.shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
							}
						}

						Button("Clear Prize Shelf") {
							if prizeShelfItems.isEmpty {
								isShowingEmptyShelfAlert = true
							} else {
								isShowingClearShelfConfirmation = true
							}
						}
							.buttonStyle(SecondaryGameButton())
							.accessibilityFocused($focusedElement, equals: .clearPrizeShelf)
					}
					.padding(.top, 8)
				},
					label: {
						Text("Prize Shelf")
							.font(.headline)
							.accessibilityLabel("Prize Shelf")
							.accessibilityValue(prizeShelfAccessibilityValue)
					}
				)
				.tint(AppTheme.heading)
				.foregroundStyle(AppTheme.heading)
				.modifier(PrizeShelfCard())
			}
			.padding(24)
		}
		.appBackground()
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.alert("Are You Sure?", isPresented: $isShowingClearShelfConfirmation) {
			Button("Yes, Clear My Shelf", role: .destructive) {
				clearPrizeShelf()
				DispatchQueue.main.async {
					isPrizeShelfExpanded = true
					focusedElement = .emptyShelfMessage
				}
			}

			Button("No, Keep My Prizes", role: .cancel) {
				DispatchQueue.main.async {
					focusedElement = .clearPrizeShelf
				}
			}
		}
		.alert("You have no Prizes!", isPresented: $isShowingEmptyShelfAlert) {
			Button("Ok!") {
				DispatchQueue.main.async {
					focusedElement = .clearPrizeShelf
				}
			}
		} message: {
			Text("You can't clear away what you don't have! Go win some tickets!")
		}
		.onChange(of: howToPlayFocusToken, initial: true) { _, _ in
			guard howToPlayFocusToken > 0 else { return }
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				focusedElement = .howToPlay
			}
		}
	}
	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}

	private var plaqueBackground: some ShapeStyle {
		LinearGradient(
			colors: [
				AppTheme.plaqueDarkStart,
				AppTheme.plaqueDarkMid,
				AppTheme.plaqueLightMid,
				AppTheme.plaqueDarkMid,
				AppTheme.plaqueDarkStart
			],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	private var prizeShelfAccessibilityValue: String {
		"\(prizeShelfCount) " + (prizeShelfCount == 1 ? "Prize" : "Prizes")
	}
}

private struct PrizeShelfCard: ViewModifier {
	func body(content: Content) -> some View {
		content
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				LinearGradient(
					colors: [AppTheme.prizeShelfTop, AppTheme.prizeShelfBottom],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			)
			.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 22, style: .continuous)
					.stroke(AppTheme.focus.opacity(0.16), lineWidth: 2)
			)
			.shadow(color: Color.black.opacity(0.3), radius: 18, x: 0, y: 10)
	}
}

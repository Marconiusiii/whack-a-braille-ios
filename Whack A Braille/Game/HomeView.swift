import SwiftUI

struct HomeView: View {

	private enum FocusTarget: Hashable {
		case heading
		case howToPlay
		case gameSettings
		case cashInTickets
		case prizeShelf
	}

	let totalTickets: Int
	let prizeShelfItems: [GameViewModel.PrizeShelfDisplayItem]
	let prizeShelfCount: Int
	let homeHeadingFocusToken: Int
	let howToPlayFocusToken: Int
	let gameSettingsFocusToken: Int
	let cashInFocusToken: Int
	let openHowToPlay: () -> Void
	let openPrizeCounter: () -> Void
	let openSettings: () -> Void
	let startGame: () -> Void
	let clearPrizeShelf: () -> Void
	let removePrizeShelfItem: (String) -> Void

	@Environment(\.colorScheme) private var colorScheme
	@State private var isShowingPrizeShelf = false
	@State private var hasFocusedInitialHeading = false
	@AccessibilityFocusState private var focusedElement: FocusTarget?

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 0) {
				VStack(alignment: .leading, spacing: 12) {
						Text("Whack A Braille")
							.font(.system(.largeTitle, design: .rounded, weight: .heavy))
							.foregroundStyle(AppTheme.title)
							.accessibilityAddTraits(.isHeader)
							.accessibilityFocused($focusedElement, equals: .heading)

//					Text("Listen sharp, type fast, and send those braille moles scampering before they duck away. Rack up tickets with Braille Screen Input, a keyboard, or your braille display, then cash in for silly prizes.")
//						.foregroundStyle(secondaryTextColor)
//						.fixedSize(horizontal: false, vertical: true)
//
				}
				.appCard()
				.accessibilityTouchRegion(minHeight: 0, topPadding: 10, bottomPadding: 4, alignment: .leading)

				VStack(alignment: .leading, spacing: 0) {
					Button("How to Play", action: openHowToPlay)
						.buttonStyle(SecondaryGameButton())
						.accessibilityTouchRegion(topPadding: 20, bottomPadding: 6, horizontalPadding: 20)
						.accessibilityFocused($focusedElement, equals: .howToPlay)

						Button("Game Settings", action: openSettings)
							.buttonStyle(SecondaryGameButton())
							.accessibilityTouchRegion(topPadding: 6, bottomPadding: 6, horizontalPadding: 20)
							.accessibilityFocused($focusedElement, equals: .gameSettings)

					Button(action: openPrizeCounter) {
						ViewThatFits(in: .horizontal) {
							HStack(spacing: 12) {
								Text("Cash In Tickets")
									.fixedSize(horizontal: false, vertical: true)
								Spacer(minLength: 12)
								ticketBadge
							}

							VStack(alignment: .center, spacing: 8) {
								Text("Cash In Tickets")
									.fixedSize(horizontal: false, vertical: true)
								ticketBadge
							}
						}
					}
						.buttonStyle(SecondaryGameButton())
							.accessibilityTouchRegion(topPadding: 6, bottomPadding: 6, horizontalPadding: 20)
							.accessibilityValue("\(totalTickets) available")
							.accessibilityHint("Opens Prize Counter")
							.accessibilityFocused($focusedElement, equals: .cashInTickets)

						Button("Start Whacking", action: startGame)
						.buttonStyle(PrimaryGameButton())
						.accessibilityTouchRegion(minHeight: 116, topPadding: 6, bottomPadding: 30, horizontalPadding: 20)
				}
				.appActionCard()
				.accessibilityTouchRegion(minHeight: 0, verticalPadding: 10, alignment: .leading)

				Button("Prize Shelf") {
					isShowingPrizeShelf = true
				}
				.buttonStyle(SecondaryGameButton())
				.accessibilityValue(prizeShelfAccessibilityValue)
					.accessibilityHint("Opens a list of all your prizes!")
					.modifier(PrizeShelfCard())
					.accessibilityTouchRegion(minHeight: 0, topPadding: 10, bottomPadding: 20, alignment: .leading)
					.accessibilityFocused($focusedElement, equals: .prizeShelf)
				}
				.padding(24)
			}
			.appBackground()
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.sheet(
				isPresented: $isShowingPrizeShelf,
				onDismiss: {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
						focusedElement = .prizeShelf
					}
				}
			) {
				PrizeShelfSheet(
				prizeShelfItems: prizeShelfItems,
				prizeShelfCount: prizeShelfCount,
				clearPrizeShelf: clearPrizeShelf,
				removePrizeShelfItem: removePrizeShelfItem
			)
			}
			.onAppear {
				guard !hasFocusedInitialHeading,
					  homeHeadingFocusToken == 0,
					  howToPlayFocusToken == 0,
					  gameSettingsFocusToken == 0,
					  cashInFocusToken == 0 else { return }
				hasFocusedInitialHeading = true
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					focusedElement = .heading
				}
			}
				.onChange(of: howToPlayFocusToken, initial: true) { _, _ in
					guard howToPlayFocusToken > 0 else { return }
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
						focusedElement = .howToPlay
					}
			}
			.onChange(of: homeHeadingFocusToken, initial: true) { _, _ in
				guard homeHeadingFocusToken > 0 else { return }
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					focusedElement = .heading
				}
			}
			.onChange(of: gameSettingsFocusToken, initial: true) { _, _ in
				guard gameSettingsFocusToken > 0 else { return }
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
						focusedElement = .gameSettings
					}
				}
				.onChange(of: cashInFocusToken, initial: true) { _, _ in
					guard cashInFocusToken > 0 else { return }
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
						focusedElement = .cashInTickets
					}
				}
			}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}

	private var ticketBadge: some View {
		Text("\(totalTickets)")
			.font(.subheadline.weight(.bold))
			.foregroundStyle(AppTheme.primaryButtonText)
			.padding(.horizontal, 10)
			.padding(.vertical, 6)
			.background(
				Capsule(style: .continuous)
					.fill(AppTheme.focus)
			)
			.fixedSize(horizontal: false, vertical: true)
			.accessibilityHidden(true)
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

private struct PrizeShelfSheet: View {

	private enum FocusTarget: Hashable {
		case clearPrizeShelf
		case emptyShelfMessage
		case prizeShelfRow(String)
	}

	let prizeShelfItems: [GameViewModel.PrizeShelfDisplayItem]
	let prizeShelfCount: Int
	let clearPrizeShelf: () -> Void
	let removePrizeShelfItem: (String) -> Void

	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme
	@State private var isShowingClearShelfConfirmation = false
	@State private var isShowingEmptyShelfAlert = false
	@State private var selectedPrizeItem: GameViewModel.PrizeShelfDisplayItem?
	@State private var lastPresentedPrizeItemID: String?
	@AccessibilityFocusState private var focusedElement: FocusTarget?

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 0) {
					VStack(alignment: .leading, spacing: 0) {
						Text(prizeShelfAccessibilityValue)
							.foregroundStyle(secondaryTextColor)
							.accessibilityTouchRegion(minHeight: 0, topPadding: 8, bottomPadding: 20, horizontalPadding: 20, alignment: .leading)
					}
					.appActionCard()

					VStack(alignment: .leading, spacing: 0) {
						if prizeShelfItems.isEmpty {
							Text("Your shelf is empty. Go bonk some moles and win something shiny!")
								.foregroundStyle(secondaryTextColor)
								.fixedSize(horizontal: false, vertical: true)
								.accessibilityTouchRegion(minHeight: 96, topPadding: 20, bottomPadding: 6, horizontalPadding: 20, alignment: .leading)
								.accessibilityFocused($focusedElement, equals: .emptyShelfMessage)
						} else {
							ForEach(prizeShelfItems) { item in
								prizeShelfRow(item)
							}
						}

						Button("Clear Prize Shelf") {
							if prizeShelfItems.isEmpty {
								isShowingEmptyShelfAlert = true
							} else {
								isShowingClearShelfConfirmation = true
							}
						}
						.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 20, verticalInset: 6))
						.frame(maxWidth: .infinity, minHeight: 76)
						.accessibilityFocused($focusedElement, equals: .clearPrizeShelf)
					}
					.appActionCard()
				}
				.padding(24)
			}
			.appBackground()
			.navigationTitle("Prize Shelf")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") {
						dismiss()
					}
				}
			}
		}
		.alert("Are You Sure?", isPresented: $isShowingClearShelfConfirmation) {
			Button("Yes, Clear My Shelf", role: .destructive) {
				clearPrizeShelf()
				DispatchQueue.main.async {
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
		.sheet(
			item: $selectedPrizeItem,
			onDismiss: {
				guard let lastPresentedPrizeItemID else { return }
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					focusedElement = .prizeShelfRow(lastPresentedPrizeItemID)
				}
			}
		) { item in
			PrizeDetailView(item: item) {
				selectedPrizeItem = nil
			}
		}
	}

	@ViewBuilder
	private func prizeShelfRow(_ item: GameViewModel.PrizeShelfDisplayItem) -> some View {
		Button {
			lastPresentedPrizeItemID = item.id
			selectedPrizeItem = item
		} label: {
			HStack {
				Text(item.displayText)
					.font(.headline)
					.foregroundStyle(AppTheme.plaqueText)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 12)
			.frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
			.background(plaqueBackground)
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(Color.white.opacity(0.16), lineWidth: 1)
			)
			.shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
			.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
		}
		.buttonStyle(.plain)
		.accessibilityTouchRegion(minHeight: 74, verticalPadding: 5, horizontalPadding: 20, alignment: .leading)
		.accessibilityFocused($focusedElement, equals: .prizeShelfRow(item.id))
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			Button(role: .destructive) {
				removePrizeShelfItem(item.id)
			} label: {
				Label("Delete", systemImage: "trash")
			}
			.accessibilityHidden(true)
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(item.displayText)
		.accessibilityAddTraits(.isButton)
		.accessibilityHint("Opens prize details.")
		.accessibilityAction(named: "Delete prize") {
			removePrizeShelfItem(item.id)
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

import SwiftUI
import UIKit

enum MoleReconPracticeMode: String, CaseIterable, Identifiable {
	case recon = "Recon"
	case grudgeMatch = "Grudge Match"

	var id: String { rawValue }
}

struct MoleReconTrainingContext {
	let reconItems: [BrailleItem]
	let grudgeMatchItems: [BrailleItem]
	let selectedMode: MoleReconPracticeMode
	let selectedGrudgeItemIDs: Set<String>
}

struct RoundResultsView: View {

	let result: RoundResult?
	let totalTickets: Int
	let moleReconContext: MoleReconTrainingContext?
	let keepWhacking: () -> Void
	let beginMoleRecon: ([BrailleItem], MoleReconTrainingContext) -> Void
	let cashInTickets: () -> Void
	let saveTicketsAndReturnHome: () -> Void
	let returnHome: () -> Void
	@Binding var speakBrailleDots: Bool

	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@AccessibilityFocusState private var isHeadingFocused: Bool
	@State private var isResultsContentAccessible = false
	@State private var isShowingMoleRecon = false

	var body: some View {
		ScrollView {
			resultContent(accessibilityLayout: usesAccessibilityLayout)
				.padding(.bottom, 24)
		}
		.appBackground()
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.sheet(isPresented: $isShowingMoleRecon) {
			if let context = currentMoleReconContext {
				MoleReconView(
					context: context,
					speakBrailleDots: $speakBrailleDots,
					beginPractice: { selectedItems, updatedContext in
						isShowingMoleRecon = false
						beginMoleRecon(selectedItems, updatedContext)
					},
					cancel: {
						isShowingMoleRecon = false
					}
				)
			}
		}
			.onAppear {
				isResultsContentAccessible = false
				isHeadingFocused = false
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					DispatchQueue.main.async {
						UIAccessibility.post(notification: .screenChanged, argument: nil)
					}
				}
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					isHeadingFocused = true
				}
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
						isResultsContentAccessible = true
					}
				}
	}

	private var usesAccessibilityLayout: Bool {
		dynamicTypeSize.isAccessibilitySize
	}

	private var headingText: String {
		result?.isTraining == true ? "Training Complete! Great Work!" : "Round Results"
	}

	private var moleReconItems: [BrailleItem] {
		guard let result else { return [] }
		return result.moleReconItems.filter { !dotPatternText(for: $0).isEmpty }
	}

	private var grudgeMatchItems: [BrailleItem] {
		guard let result else { return [] }
		return result.grudgeMatchItems.filter { !dotPatternText(for: $0).isEmpty }
	}

	private var currentMoleReconContext: MoleReconTrainingContext? {
		if let moleReconContext {
			return moleReconContext
		}

		let reconItems = moleReconItems
		let grudgeMatchItems = grudgeMatchItems
		guard !reconItems.isEmpty || !grudgeMatchItems.isEmpty else { return nil }

		return MoleReconTrainingContext(
			reconItems: reconItems,
			grudgeMatchItems: grudgeMatchItems,
			selectedMode: reconItems.isEmpty ? .grudgeMatch : .recon,
			selectedGrudgeItemIDs: Set(grudgeMatchItems.map(\.id))
		)
	}

	private func resultContent(accessibilityLayout: Bool) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			if let result {
				VStack(alignment: .leading, spacing: 12) {
					Text(headingText)
						.font(.system(.largeTitle, design: .rounded, weight: .heavy))
						.foregroundStyle(AppTheme.heading)
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityAddTraits(.isHeader)
						.accessibilityFocused($isHeadingFocused)

					if !result.isTraining {
						Text(resultsFlavorLine(for: result))
							.font(.headline)
							.foregroundStyle(primaryTextColor)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.appCard()
				.accessibilityTouchRegion(minHeight: 0, topPadding: 24, bottomPadding: 10, horizontalPadding: 24, alignment: .leading)

				VStack(alignment: .leading, spacing: 0) {
					if !result.isTraining {
						VStack(alignment: .leading, spacing: 6) {
							Text("Score: \(result.score)")
							Text("Accuracy: \(accuracyPercent(for: result)) percent")
						}
						.fixedSize(horizontal: false, vertical: true)
						.summaryRowCard()
						.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						.accessibilityElement(children: .combine)

						VStack(alignment: .leading, spacing: 4) {
							Text("Hits: \(result.hits), Misses: \(result.misses), Escapes: \(result.escapes)")
						}
						.fixedSize(horizontal: false, vertical: true)
						.summaryRowCard()
						.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						.accessibilityElement(children: .combine)

						VStack(alignment: .leading, spacing: 4) {
							Text("Best streak: \(result.bestStreak), Speed bonus: \(result.speedBonusTickets) \(result.speedBonusTickets == 1 ? "ticket" : "tickets")")
						}
						.fixedSize(horizontal: false, vertical: true)
						.summaryRowCard()
						.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						.accessibilityElement(children: .combine)

						VStack(alignment: .leading, spacing: 4) {
							Text("Tickets earned: \(result.totalTickets)")
							Text("Total tickets: \(totalTickets)")
						}
						.fixedSize(horizontal: false, vertical: true)
						.summaryRowCard()
						.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
						.accessibilityElement(children: .combine)
					} else {
						Text("Training moles completed: \(result.trainingMolesCompleted)")
							.fixedSize(horizontal: false, vertical: true)
							.summaryRowCard()
							.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
					}

				}
				.foregroundStyle(primaryTextColor)
				.appCard()
				.accessibilityTouchRegion(minHeight: 0, topPadding: 10, bottomPadding: 0, horizontalPadding: 24, alignment: .leading)
				.accessibilityHidden(!isResultsContentAccessible)

				Button(result.isTraining ? "Keep Training!" : "Keep Whacking!", action: keepWhacking)
					.buttonStyle(FullRegionPrimaryGameButton(visibleMinHeight: 72, horizontalInset: 24, verticalInset: 20))
					.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 120 : 96)
					.accessibilityHidden(!isResultsContentAccessible)

				if result.isTraining, currentMoleReconContext != nil {
					Button("Back to Recon") {
						isShowingMoleRecon = true
					}
					.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 24, verticalInset: 20))
					.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 104 : 88)
					.accessibilityHint("Opens Mole Recon to adjust this training session.")
					.accessibilityHidden(!isResultsContentAccessible)
				}

				if !result.isTraining && currentMoleReconContext != nil {
					Button("Mole Recon") {
						isShowingMoleRecon = true
					}
					.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 24, verticalInset: 20))
					.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 104 : 88)
					.accessibilityHint("Opens Mole Recon training options for this round's moles.")
					.accessibilityHidden(!isResultsContentAccessible)
				}

				if result.isTraining {
					Button("Return Home", action: returnHome)
						.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 24, verticalInset: 20))
						.frame(maxWidth: .infinity, minHeight: accessibilityLayout ? 104 : 88)
						.accessibilityHidden(!isResultsContentAccessible)
				} else {
					VStack(spacing: 0) {
						bottomActionButtons(minHeight: accessibilityLayout ? 104 : 88)
					}
					.accessibilityHidden(!isResultsContentAccessible)
				}
			}
		}
	}

	@ViewBuilder
	private func bottomActionButtons(minHeight: CGFloat) -> some View {
		Button("Save Tickets", action: saveTicketsAndReturnHome)
			.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 16, verticalInset: 20))
			.frame(maxWidth: .infinity, minHeight: minHeight)
			.accessibilityLabel("Save Tickets and Return Home")

		Button("Cash In", action: cashInTickets)
			.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 16, verticalInset: 20))
			.frame(maxWidth: .infinity, minHeight: minHeight)
			.accessibilityLabel("Cash In Tickets and Pick a Prize")
	}

	private var primaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}

	private func accuracyPercent(for result: RoundResult) -> Int {
		let attempts = result.hits + result.misses + result.escapes
		guard attempts > 0 else { return 0 }
		return Int((Double(result.hits) / Double(attempts) * 100).rounded())
	}

	private func resultsFlavorLine(for result: RoundResult) -> String {
		let accuracy = accuracyPercent(for: result)

		if result.hits == 0 {
			return "The moles won this round. Rude, but temporary."
		}

		if accuracy >= 90 && result.escapes == 0 {
			return "You brought study skills to a bonk fight."
		}

		if result.bestStreak >= 10 {
			return "Fast hands. Suspiciously fast."
		}

		if result.escapes >= result.hits {
			return "The escaped moles are acting brave. For now."
		}

		if result.misses + result.escapes >= result.hits {
			return "That was valuable reconnaissance disguised as chaos."
		}

		if accuracy >= 75 {
			return "Braille fluency increased. Mole confidence decreased."
		}

		return "A few moles got away, but they know you're learning."
	}
}

private struct MoleReconView: View {

	let context: MoleReconTrainingContext
	@Binding var speakBrailleDots: Bool
	let beginPractice: ([BrailleItem], MoleReconTrainingContext) -> Void
	let cancel: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dismiss) private var dismiss
	@AccessibilityFocusState private var isHeadingFocused: Bool
	@State private var selectedMode: MoleReconPracticeMode = .recon
	@State private var selectedItemIDs = Set<String>()
	@State private var isShowingEmptySelectionAlert = false

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 0) {
					VStack(alignment: .leading, spacing: 12) {
						Text("Mole Recon")
							.font(.system(.largeTitle, design: .rounded, weight: .heavy))
							.foregroundStyle(AppTheme.heading)
							.fixedSize(horizontal: false, vertical: true)
							.accessibilityAddTraits(.isHeader)
							.accessibilityFocused($isHeadingFocused)

						Picker("Mole Recon mode", selection: $selectedMode) {
							ForEach(availableModes) { mode in
								Text(mode.rawValue).tag(mode)
							}
						}
						.pickerStyle(.segmented)
						.accessibilityHint("Changes the Mole Recon training target list.")

						Text(moleReconBlurb)
							.foregroundStyle(secondaryTextColor)
							.fixedSize(horizontal: false, vertical: true)

						Toggle("Speak Braille Dots", isOn: $speakBrailleDots)
							.foregroundStyle(primaryTextColor)
							.fixedSize(horizontal: false, vertical: true)
					}
					.appCard()
					.accessibilityTouchRegion(minHeight: 0, topPadding: 24, bottomPadding: 10, horizontalPadding: 24, alignment: .leading)

					VStack(alignment: .leading, spacing: 0) {
						ForEach(displayedItems, id: \.id) { item in
							if activeMode == .grudgeMatch {
								interactiveMoleRow(for: item)
							} else {
								staticMoleRow(for: item)
							}
						}
					}
					.foregroundStyle(primaryTextColor)
					.appCard()
					.accessibilityTouchRegion(minHeight: 0, topPadding: 10, bottomPadding: 0, horizontalPadding: 24, alignment: .leading)

					Button("Begin Practice") {
						let practiceItems = selectedPracticeItems
						if practiceItems.isEmpty {
							isShowingEmptySelectionAlert = true
							return
						}
						dismiss()
						beginPractice(practiceItems, updatedContext)
					}
					.buttonStyle(FullRegionPrimaryGameButton(visibleMinHeight: 72, horizontalInset: 24, verticalInset: 20))
					.accessibilityHint("Starts a training round using the moles in Mole Recon.")

					Button("Cancel") {
						dismiss()
						cancel()
					}
					.buttonStyle(FullRegionSecondaryGameButton(horizontalInset: 24, verticalInset: 20))
				}
				.padding(.bottom, 24)
			}
			.appBackground()
		}
		.alert("No Moles Selected", isPresented: $isShowingEmptySelectionAlert) {
			Button("OK", role: .cancel) {}
		} message: {
			Text("Pick at least one mole. An empty recon mission is just dramatic standing around with nothing to whack.")
		}
		.onAppear {
			selectedMode = context.selectedMode
			selectedItemIDs = context.selectedGrudgeItemIDs.isEmpty
				? Set(context.grudgeMatchItems.map(\.id))
				: context.selectedGrudgeItemIDs
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
				isHeadingFocused = true
			}
		}
	}

	private var availableModes: [MoleReconPracticeMode] {
		MoleReconPracticeMode.allCases.filter { mode in
			switch mode {
			case .recon:
				return !context.reconItems.isEmpty
			case .grudgeMatch:
				return !context.grudgeMatchItems.isEmpty
			}
		}
	}

	private var activeMode: MoleReconPracticeMode {
		availableModes.contains(selectedMode) ? selectedMode : (availableModes.first ?? .grudgeMatch)
	}

	private var moleReconBlurb: String {
		if activeMode == .grudgeMatch {
			return "Have a grudge against these particular moles? Show them what's what in this training session! Choose the moles you want to whack:"
		}

		return "These moles remain at large. Study their dot patterns, prepare your fingers, and begin a training round so they don't get away twice."
	}

	private var displayedItems: [BrailleItem] {
		activeMode == .grudgeMatch ? context.grudgeMatchItems : context.reconItems
	}

	private var selectedPracticeItems: [BrailleItem] {
		if activeMode == .grudgeMatch {
			return context.grudgeMatchItems.filter { selectedItemIDs.contains($0.id) }
		}

		return context.reconItems
	}

	private var updatedContext: MoleReconTrainingContext {
		MoleReconTrainingContext(
			reconItems: context.reconItems,
			grudgeMatchItems: context.grudgeMatchItems,
			selectedMode: activeMode,
			selectedGrudgeItemIDs: selectedItemIDs
		)
	}

	@ViewBuilder
	private func interactiveMoleRow(for item: BrailleItem) -> some View {
		Toggle(isOn: selectionBinding(for: item)) {
			moleRowContent(for: item)
		}
		.toggleStyle(MoleReconSelectionToggleStyle())
		.summaryRowCard()
		.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("\(item.announceText), \(dotPatternText(for: item))")
		.accessibilityHint("Toggles mole selection")
		.accessibilityAddTraits(.isButton)
		.accessibilityAddTraits(selectedItemIDs.contains(item.id) ? .isSelected : [])
		.accessibilityRemoveTraits(selectedItemIDs.contains(item.id) ? [] : .isSelected)
	}

	private func staticMoleRow(for item: BrailleItem) -> some View {
		moleRowContent(for: item)
			.summaryRowCard()
			.accessibilityTouchRegion(verticalPadding: 5, alignment: .leading)
			.accessibilityElement(children: .ignore)
			.accessibilityLabel("\(item.announceText), \(dotPatternText(for: item))")
	}

	private func moleRowContent(for item: BrailleItem) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(item.displayLabel)
				.font(.headline)
				.fixedSize(horizontal: false, vertical: true)
			Text(dotPatternText(for: item))
				.foregroundStyle(secondaryTextColor)
				.fixedSize(horizontal: false, vertical: true)
		}
	}

	private func selectionBinding(for item: BrailleItem) -> Binding<Bool> {
		Binding(
			get: {
				selectedItemIDs.contains(item.id)
			},
			set: { isSelected in
				if isSelected {
					selectedItemIDs.insert(item.id)
				} else {
					selectedItemIDs.remove(item.id)
				}
			}
		)
	}

	private var primaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}
}

private struct MoleReconSelectionToggleStyle: ToggleStyle {

	func makeBody(configuration: Configuration) -> some View {
		Button {
			configuration.isOn.toggle()
		} label: {
			HStack(alignment: .firstTextBaseline, spacing: 12) {
				Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
					.imageScale(.large)
					.foregroundStyle(configuration.isOn ? AppTheme.heading : AppTheme.focus.opacity(0.7))
					.accessibilityHidden(true)

				configuration.label
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
}

private func dotPatternText(for item: BrailleItem) -> String {
	let sequence = item.perkinsSequenceDots.isEmpty ? [item.dots] : item.perkinsSequenceDots
	let cells = sequence
		.filter { !$0.isEmpty }
		.map { dots in
			let label = dots.count == 1 ? "Dot" : "Dots"
			return "\(label) \(dots.map(String.init).joined(separator: " "))"
		}

	return cells.joined(separator: ", then ")
}

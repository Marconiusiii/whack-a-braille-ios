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

					Text(result.isTraining ? trainingFlavorLine(for: result) : resultsFlavorLine(for: result))
						.font(.headline)
						.foregroundStyle(primaryTextColor)
						.fixedSize(horizontal: false, vertical: true)
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
							Text("\(result.completedTargetLabel): \(result.hits), Misses: \(result.misses), Escapes: \(result.escapes)")
							if let wordInputLabel = result.wordInputLabel {
								Text("\(wordInputLabel): \(result.lettersWhacked)")
							}
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
						Text("\(result.trainingCompletedLabel): \(result.trainingMolesCompleted)")
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
					.accessibilityHint("Opens Mole Recon training options for this round's \(result.reconTargetNoun).")
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
			return selectedFlavorLine(from: veryRoughFlavorLines, for: result)
		}

		if accuracy >= 90 && result.escapes == 0 {
			return selectedFlavorLine(from: excellentFlavorLines, for: result)
		}

		if accuracy >= 75 {
			return selectedFlavorLine(from: strongFlavorLines, for: result)
		}

		if accuracy >= 45 {
			return selectedFlavorLine(from: mixedFlavorLines, for: result)
		}

		return selectedFlavorLine(from: roughFlavorLines, for: result)
	}

	private func trainingFlavorLine(for result: RoundResult) -> String {
		let accuracy = accuracyPercent(for: result)

		if result.hits == 0 || accuracy < 45 {
			return selectedFlavorLine(from: roughTrainingFlavorLines, for: result)
		}

		if accuracy >= 90 && result.escapes == 0 {
			return selectedFlavorLine(from: excellentTrainingFlavorLines, for: result)
		}

		return selectedFlavorLine(from: strongTrainingFlavorLines, for: result)
	}

	private func selectedFlavorLine(from lines: [String], for result: RoundResult) -> String {
		guard !lines.isEmpty else { return "" }
		let seed = result.score + result.hits * 31 + result.misses * 17 + result.escapes * 13 + result.bestStreak * 7 + result.speedBonusTickets * 5 + result.totalTickets
		return lines[abs(seed) % lines.count]
	}

	private var excellentFlavorLines: [String] {
		[
			"Clean round! The moles popped up and immediately regretted the schedule.",
			"Every dot got read, every mole got the message.",
			"That was pure arcade bonk poetry.",
			"The hammer was singing, the dots were clicking, and the moles were doomed.",
			"Beautiful round. The moles barely had time to blink.",
			"That was a dazzling display of braille-powered whackery.",
			"The prize counter just got nervous.",
			"You read the dots and brought the bonks. Simple. Elegant. Loud.",
			"Dots read, moles bonked, arcade delighted.",
			"Fast hands. Suspiciously fast.",
			"Braille literacy: now with extra bonk velocity.",
			"That round had Grade A dot-to-hammer translation."
		]
	}

	private var strongFlavorLines: [String] {
		[
			"Solid bonking! The moles are pretending they planned it that way.",
			"Nice work. The dots lined up and the moles got thumped.",
			"You kept the rhythm and the arcade kept cheering.",
			"Good round. Several moles are now reconsidering their pop-up choices.",
			"Your hammer and your braille brain were clearly in sync.",
			"That was a tasty little serving of arcade thwack.",
			"The moles brought nonsense. You brought dot knowledge.",
			"Strong whacks, sharp reads, excellent mole confusion.",
			"Sharp reading, clean bonking, nervous moles.",
			"Your dot game had excellent thwap timing.",
			"The dots clicked and the bonks landed.",
			"Braille focus strong. Mole confidence weak."
		]
	}

	private var mixedFlavorLines: [String] {
		[
			"Some moles got away, but plenty got bonked with style.",
			"A little chaos, a little triumph, a lot of arcade noise.",
			"Not bad! The moles had tricks, but your hammer had opinions.",
			"The dots got spicy, but you stayed in the game.",
			"Some bonks landed, some moles escaped, and the arcade remains entertained.",
			"That round had wobble, but it also had whacks.",
			"A respectable rumble with a few slippery moles.",
			"The moles caused trouble, but they did not leave unbothered.",
			"Braille practice happened, moles were bonked, and the arcade survived.",
			"The dots had meaning, and the moles had problems.",
			"You turned braille cells into bonk instructions.",
			"Dot by dot, thwack by thwack, the moles learned."
		]
	}

	private var roughFlavorLines: [String] {
		[
			"Tough round. The moles are getting smug, which is always a mistake.",
			"The moles slipped away today, but revenge has excellent rhythm.",
			"That one got messy. The next bonk is already warming up.",
			"The arcade says shake it off and whack again.",
			"The moles had a good run. Suspiciously temporary.",
			"Rough one, but the hammer is still hungry.",
			"The dots got rowdy and the moles took advantage.",
			"Some rounds are training. Some rounds are mole propaganda. This was both.",
			"The moles got slippery, but the dots are still on your side.",
			"Tough round. The next cell is a fresh whack opportunity.",
			"The hammer missed a few, but your braille brain is still charging.",
			"The dots got rowdy, but you are still in the bonk zone."
		]
	}

	private var veryRoughFlavorLines: [String] {
		[
			"The moles got away with absolute foolishness.",
			"That round was mostly moles doing crimes with dots attached.",
			"The hammer demands a rematch.",
			"The arcade is chanting your comeback music.",
			"The moles are feeling brave. Terrible idea.",
			"Not your finest bonk parade, but the comeback is loading.",
			"A suspicious number of moles remain unbonked.",
			"The moles won this skirmish. The next round has other plans.",
			"The moles won this round. Rude, but temporary.",
			"Rough bonks happen. The arcade believes in the comeback."
		]
	}

	private var excellentTrainingFlavorLines: [String] {
		[
			"Beautiful training round. The moles barely got to participate.",
			"Those dots got recognized with authority.",
			"Clean practice. The hammer and braille brain are syncing nicely.",
			"That was excellent dot-to-bonk translation.",
			"Sharp dots, clean thwacks, nervous moles.",
			"You practiced so well the moles are requesting easier homework.",
			"That training round had premium whack energy.",
			"Your braille skills just made the moles flinch.",
			"Training complete. The next real round should be interesting.",
			"That was a polished little festival of practice bonks."
		]
	}

	private var strongTrainingFlavorLines: [String] {
		[
			"Training complete. The moles are pretending they were not worried.",
			"Practice bonks logged. Mole confidence reduced.",
			"Nice training round. The dots got clearer and the moles got quieter.",
			"You practiced the pattern, then introduced it to the hammer.",
			"Training works. The moles hate that.",
			"Your braille brain just got another arcade upgrade.",
			"Good practice. The dots are starting to behave.",
			"You turned practice into a tiny mole crisis.",
			"Training round complete. The hammer learned things.",
			"The moles came for practice and found consequences.",
			"That is how dot knowledge becomes bonk power.",
			"Every practice round makes the next mole sweat a little more.",
			"Those dots are getting less mysterious and more whackable.",
			"Practice today, mole panic tomorrow.",
			"The hammer is improving because the reader is improving.",
			"Your future rounds just got a little scarier for the moles.",
			"Excellent training energy. Deeply inconvenient for mole-kind.",
			"Training complete. The bonk strategy is getting sharper.",
			"This was a fine session of pre-bonk science.",
			"The arcade has detected improved thwack readiness."
		]
	}

	private var roughTrainingFlavorLines: [String] {
		[
			"Tough practice still counts. The moles do not get to vote on that.",
			"Training is where messy bonks become mighty bonks.",
			"A few patterns fought back, but you stayed in the arcade.",
			"Practice rounds are allowed to wobble. That is why they are practice.",
			"The dots got spicy, but you kept showing up.",
			"Even missed training moles are teaching you where to swing next.",
			"That round had chaos, but also progress. The arcade accepts this.",
			"The moles got slippery, but your next attempt has more data.",
			"Training complete. The comeback is now warming up.",
			"A rough practice round is just future accuracy stretching first."
		]
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
		if isBlitzContext {
			if activeMode == .grudgeMatch {
				return "Have a grudge against these particular words? Choose the ones you want back on the board, then spell them into a proper mole panic."
			}

			return "These words remain at large. Study their letter patterns and begin a training round so the whole gang doesn't get away twice."
		}

		if activeMode == .grudgeMatch {
			return "Have a grudge against these particular moles? Show them what's what in this training session! Choose the moles you want to whack:"
		}

		return "These moles remain at large. Study their dot patterns, prepare your fingers, and begin a training round so they don't get away twice."
	}

	private var isBlitzContext: Bool {
		(context.reconItems + context.grudgeMatchItems)
			.contains { item in item.modeTags.contains(where: BlitzWord.isBlitzMode) }
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

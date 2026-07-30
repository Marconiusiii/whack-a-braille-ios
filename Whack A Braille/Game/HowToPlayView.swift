import SwiftUI

struct HowToPlayView: View {

	private enum FocusTarget: Hashable {
		case heading
	}

	let onDismissRequest: () -> Void

	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme
	@AccessibilityFocusState private var focusedElement: FocusTarget?
	@State private var isInputInstructionsExpanded = false
	@State private var isGameSettingsInfoExpanded = false
	@State private var isMoleBlitzExpanded = false
	@State private var isBrailleReferenceExpanded = false

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 0) {
					VStack(alignment: .leading, spacing: 0) {
						Text("Listen for the mole, type the right answer before it ducks away, and keep the tickets rolling in. The tougher the challenge, the shinier the bragging rights.")
							.foregroundStyle(secondaryTextColor)
							.fixedSize(horizontal: false, vertical: true)
							.accessibilityTouchRegion(minHeight: 0, topPadding: 20, bottomPadding: 20, horizontalPadding: 20, alignment: .leading)
					}
					.appActionCard()

						DisclosureGroup(
							isExpanded: $isInputInstructionsExpanded,
							content: {
							VStack(alignment: .leading, spacing: 0) {
								Text("You can use an external keyboard, a braille display, braille screen input, or one-handed braille input to whack the moles as they appear.")
									.foregroundStyle(secondaryTextColor)
									.fixedSize(horizontal: false, vertical: true)
									.accessibilityTouchRegion(minHeight: 0, topPadding: 8, bottomPadding: 8, alignment: .leading)

								Text("When numbers are part of the current mole set, use the literary braille number sign before the number cell. The game gives number targets and other multi-cell answers a little more time so you can enter them accurately.")
									.foregroundStyle(secondaryTextColor)
									.fixedSize(horizontal: false, vertical: true)
									.accessibilityTouchRegion(minHeight: 0, verticalPadding: 8, alignment: .leading)

								inputInstructionSection(
									title: "Standard Keyboard or 8-Dot Braille",
									rows: [
										"When the Keyboard Mallet area appears, whack away anytime. Type the target as soon as you hear it.",
										"8-dot has limitations for Grade 2 Dots 4 5 6 contractions, so these will be filtered out in this mode."
									]
								)

								inputInstructionSection(
									title: "Braille Display Input",
									rows: [
										"Use this mode when using an external braille display with Uncontracted and Contracted braille tables.",
										"Pick the correct braille table for the mole set before starting the round, then press Space, Return, or Dot 8 after typing the correct characters to whack the mole.",
										"Grade 2 suffixes will not be available in this mode."
									]
								)

								inputInstructionSection(
									title: "Braille Screen Input",
									rows: [
										"Set the correct braille table before starting a round. Use Contracted for the Grade 2 moles and Uncontracted for the Grade 1 moles.",
										"Type the answer, then swipe right with one or two fingers to whack the mole. You can whack with Space, Return, or the Translation gesture.",
										"This mode gives you a little more time to enter the correct characters before whacking the mole.",
										"Grade 2 suffixes will not be available in this mode.",
										"When the round ends, make sure to turn braille screen input mode off in the Round Results screen."
									]
								)

								inputInstructionSection(
									title: "One-Handed Braille Input",
									rows: [
										"Use this mode when entering braille one column at a time.",
										"Type the first column, type the second column, then swipe to submit the character.",
										"The moles stay up longer in this mode so the extra one-handed submit step has room to breathe.",
										"Grade 2 suffixes will not be available in this mode."
									]
								)

								inputInstructionSection(
									title: "Perkins Home Row",
									rows: [
										"When the Keyboard Mallet area appears, whack away anytime.",
										"Letters S, D, and F are Dots 3, 2, and 1 respectively, Letters J, K, and L are dots 4 , 5, and 6.",
										"Great for fast entry and practicing tabletop and Perkins entry."
									]
								)
							}
						},
						label: {
							Text("Input Instructions")
								.font(.headline)
								.foregroundStyle(AppTheme.heading)
								.fixedSize(horizontal: false, vertical: true)
								.accessibilityTouchRegion(minHeight: 0, topPadding: 20, bottomPadding: 8, alignment: .leading)
								.accessibilityAddTraits(.isHeader)
						}
					)
						.tint(AppTheme.heading)
						.foregroundStyle(AppTheme.heading)
						.appActionCard()

						DisclosureGroup(
							isExpanded: $isMoleBlitzExpanded,
							content: {
								VStack(alignment: .leading, spacing: 0) {
									section(
										title: "3 Letter Words",
										rows: [
											"Three letter moles pop up together with one letter apiece. Type the word from left to right and bonk each mole in spelling order.",
											"Finish the word before time runs out or the whole word escapes as one slippery team."
										]
									)

									section(
										title: "4 Letter Words",
										rows: [
											"Four moles spread themselves across the board and dare you to spell their word in order.",
											"Each correct letter earns its own bonk. One wrong key counts as a miss, but the word stays up until you finish it or time runs out."
										]
									)

									section(
										title: "Grade 1 Mole Blitz",
										rows: [
											"Three, four, and five letter words take turns storming the board. The layout changes with each word, so keep your ears ready and your spelling hammer warmer.",
											"Longer words take more work and earn richer ticket rewards."
										]
									)

									section(
										title: "Blitz Training and Mole Recon",
										rows: [
											"Training removes the timer so you can practice whole words without pressure. Repeat Current Word speaks the target again whenever you need it.",
											"Mole Recon remembers missed and escaped words, while Grudge Match lets you practice any word that appeared in the round."
										]
									)
								}
							},
							label: {
								Text("Mole Blitz")
									.font(.headline)
									.foregroundStyle(AppTheme.heading)
									.fixedSize(horizontal: false, vertical: true)
									.accessibilityTouchRegion(minHeight: 0, topPadding: 20, bottomPadding: 8, alignment: .leading)
									.accessibilityAddTraits(.isHeader)
							}
						)
						.tint(AppTheme.heading)
						.foregroundStyle(AppTheme.heading)
						.appActionCard()

						DisclosureGroup(
							isExpanded: $isGameSettingsInfoExpanded,
							content: {
								VStack(alignment: .leading, spacing: 0) {
									section(
										title: "Mole Chooser",
										rows: [
											"Each mole set changes what pops up for you to type, from Grade 1 letters and numbers to Grade 2 contractions and whole-word signs.",
											"Invasion mode keeps things wild by picking random characters out of the entire set when each mole appears rather than using just 5 chosen at the start of a normal round.",
											"Custom Moles lets you hand-pick 5 favorite targets or assemble your own Invasion Army when certain moles have simply had it too good for too long."
										]
									)

									section(
										title: "Difficulty Modes",
										rows: [
											"Beginner gives you a roomier hit window, Normal keeps the pace lively, and Supreme turns the mole machine into pure chaos.",
											"Training mode slows things down and lets you practice without the usual round pressure."
										]
									)

									section(
										title: "Spatial Mole Mapping",
										rows: [
											"Turn this on if you want mole positions to line up with the keyboard lanes, which can make the board feel more predictable under your fingers.",
											"Leave it off if you want the moles to feel a little more sneaky."
										]
									)

									section(
										title: "Training",
										rows: [
											"Training is the friendly practice room. It helps you focus on accuracy, braille dots, and repeating targets before jumping into the timed arcade rush.",
											"When training ends, you can head straight back home or jump right into another practice round."
										]
									)
								}
							},
							label: {
								Text("Game Settings Info")
									.font(.headline)
									.foregroundStyle(AppTheme.heading)
									.fixedSize(horizontal: false, vertical: true)
									.accessibilityTouchRegion(minHeight: 0, topPadding: 20, bottomPadding: 8, alignment: .leading)
									.accessibilityAddTraits(.isHeader)
							}
						)
						.tint(AppTheme.heading)
						.foregroundStyle(AppTheme.heading)
						.appActionCard()

						DisclosureGroup(
						isExpanded: $isBrailleReferenceExpanded,
						content: {
							VStack(alignment: .leading, spacing: 0) {
								Text("Use this as a quick guide for the Grade 1 and Grade 2 patterns used in the game.")
									.foregroundStyle(secondaryTextColor)
									.fixedSize(horizontal: false, vertical: true)
									.accessibilityTouchRegion(minHeight: 0, topPadding: 8, bottomPadding: 8, alignment: .leading)

								ForEach(BrailleRegistry.grade1ReferenceSections) { section in
									referenceSection(section)
								}

								ForEach(BrailleRegistry.grade2ReferenceSections) { section in
									referenceSection(section)
								}
							}
						},
						label: {
							Text("Braille Reference")
								.font(.headline)
								.foregroundStyle(AppTheme.heading)
								.fixedSize(horizontal: false, vertical: true)
								.accessibilityTouchRegion(minHeight: 0, topPadding: 20, bottomPadding: 8, alignment: .leading)
								.accessibilityAddTraits(.isHeader)
						}
					)
					.tint(AppTheme.heading)
					.foregroundStyle(AppTheme.heading)
					.appActionCard()
				}
				.padding(24)
			}
			.scrollContentBackground(.hidden)
			.background(backgroundView)
			.navigationTitle("How to Play")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done", action: dismissHowToPlay)
				}
			}
		}
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				focusedElement = .heading
			}
		}
	}

	private func section(title: String, rows: [String]) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(title)
				.font(.title3.weight(.bold))
				.foregroundStyle(AppTheme.heading)
				.accessibilityTouchRegion(minHeight: 0, topPadding: 20, bottomPadding: 8, alignment: .leading)
				.accessibilityAddTraits(.isHeader)

			ForEach(rows, id: \.self) { row in
				Text(row)
					.foregroundStyle(secondaryTextColor)
					.fixedSize(horizontal: false, vertical: true)
					.accessibilityTouchRegion(minHeight: 0, verticalPadding: 8, alignment: .leading)
			}
		}
		.appActionCard()
	}

	private func inputInstructionSection(title: String, rows: [String]) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(title)
				.font(.title3.weight(.bold))
				.foregroundStyle(AppTheme.heading)
				.accessibilityTouchRegion(minHeight: 0, topPadding: 12, bottomPadding: 8, alignment: .leading)
				.accessibilityAddTraits(.isHeader)

			ForEach(rows, id: \.self) { row in
				HStack(alignment: .top, spacing: 10) {
					Text("•")
						.foregroundStyle(AppTheme.heading)
					Text(row)
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
				.accessibilityTouchRegion(minHeight: 0, verticalPadding: 8, alignment: .leading)
				.accessibilityElement(children: .combine)
			}
		}
	}

	private func referenceSection(_ section: BrailleRegistry.ReferenceSection) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(section.title)
				.font(.title3.weight(.bold))
				.foregroundStyle(AppTheme.heading)
				.accessibilityTouchRegion(minHeight: 0, topPadding: 12, bottomPadding: 8, alignment: .leading)
				.accessibilityAddTraits(.isHeader)

			ForEach(section.rows) { row in
				VStack(alignment: .leading, spacing: 4) {
					Text(row.displayLabel)
						.font(.headline)
						.foregroundStyle(primaryTextColor)
						.fixedSize(horizontal: false, vertical: true)

					Text("Braille Dots: \(row.dotsText)")
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)

					Text("Braille Unicode: \(row.unicodeText)")
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityHidden(true)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(12)
				.accessibilityTouchRegion(minHeight: 72, verticalPadding: 5, alignment: .leading)
				.background(
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.fill(colorScheme == .dark ? AppTheme.darkCard : AppTheme.lightCard)
				)
				.accessibilityElement(children: .combine)
			}
		}
	}

	private var primaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkText : AppTheme.lightText
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}

	private var backgroundView: some View {
		LinearGradient(
			colors: colorScheme == .dark
				? [AppTheme.darkBackgroundTop, AppTheme.darkBackgroundBottom]
				: [AppTheme.lightBackgroundTop, AppTheme.lightBackgroundBottom],
			startPoint: .top,
			endPoint: .bottom
		)
		.ignoresSafeArea()
	}

	private func dismissHowToPlay() {
		onDismissRequest()
		dismiss()
	}
}

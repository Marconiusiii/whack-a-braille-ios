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
	@State private var isBrailleReferenceExpanded = false

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					VStack(alignment: .leading, spacing: 12) {
						Text("Quick Start")
							.font(.system(.title2, design: .rounded, weight: .bold))
							.foregroundStyle(AppTheme.heading)
							.accessibilityAddTraits(.isHeader)
							.accessibilityFocused($focusedElement, equals: .heading)

						Text("Listen for the mole, type the right answer before it ducks away, and keep the tickets rolling in. The tougher the challenge, the shinier the bragging rights.")
							.foregroundStyle(secondaryTextColor)
							.fixedSize(horizontal: false, vertical: true)
					}
					.appCard()

					section(
						title: "Mole Chooser",
						rows: [
							"Each mole set changes what pops up for you to type, from Grade 1 letters and numbers to Grade 2 contractions and whole-word signs.",
							"Invasion mode keeps things wild by picking random characters out of the entire set when each mole appears rather than using just 5 chosen at the start of a normal round."
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

					DisclosureGroup(
						isExpanded: $isInputInstructionsExpanded,
						content: {
							VStack(alignment: .leading, spacing: 16) {
								Text("You can use an external keyboard, a braille display, or braille screen input to whack the moles as they appear.")
									.foregroundStyle(secondaryTextColor)
									.fixedSize(horizontal: false, vertical: true)

								Text("When numbers are part of the current mole set, use the literary braille number sign before the number cell. The game gives number targets and other multi-cell answers a little more time so you can enter them accurately.")
									.foregroundStyle(secondaryTextColor)
									.fixedSize(horizontal: false, vertical: true)

								inputInstructionSection(
									title: "Standard Keyboard or 8-Dot Braille",
									rows: [
										"This is the fast lane. Type the answer and the mole gets bonked right away.",
										"If you are using an 8-dot braille display, uncontracted-style entry works best here because every little dot pattern needs to show up quickly.",
										"The tricky Grade 2 contractions that start with dots 4 5 6 are left out of this direct mode on purpose, since some displays never send that opening cell clearly enough for a fair whack."
									]
								)

								inputInstructionSection(
									title: "Braille Display Input",
									rows: [
										"Use this mode when you want your braille display to type into the entry box and let iOS handle the translation.",
										"Pick the braille table that fits the mole set you are playing, then type the full answer and press Dot 8, Space, or Return to whack the mole.",
										"This is the best choice for contracted braille play, longer Grade 2 answers, and the dot 4 5 6 families that do not behave nicely in the fast direct mode."
									]
								)

								inputInstructionSection(
									title: "Braille Screen Input",
									rows: [
										"Set the table that matches the moles before you start. Contracted is great for Grade 2, and uncontracted is the right fit for Grade 1.",
										"Type the answer, then swipe right with one or two fingers to whack the current mole.",
										"The moles wait a little longer in this mode so you have time to finish the answer and still land the bonk.",
										"When the round ends, remember to turn Braille Screen Input back off so the results and prize screens behave normally."
									]
								)

								inputInstructionSection(
									title: "Perkins Home Row",
									rows: [
										"Think of this as turning the keyboard into a tiny braille writer. S, D, and F make dots 3, 2, and 1, while J, K, and L make dots 4, 5, and 6.",
										"For numbers and the longer Grade 2 sets, enter each cell in order and let the game keep track of the sequence for you.",
										"If you want the full literary braille workout without changing input tables, this is a wonderfully stubborn way to play."
									]
								)
							}
							.padding(.top, 8)
						},
						label: {
							Text("Input Instructions")
								.font(.headline)
								.foregroundStyle(AppTheme.heading)
								.accessibilityAddTraits(.isHeader)
						}
					)
					.tint(AppTheme.heading)
					.foregroundStyle(AppTheme.heading)
					.appCard()

					DisclosureGroup(
						isExpanded: $isBrailleReferenceExpanded,
						content: {
							VStack(alignment: .leading, spacing: 16) {
								Text("Use this as a quick guide for the Grade 1 and Grade 2 patterns used in the game.")
									.foregroundStyle(secondaryTextColor)
									.fixedSize(horizontal: false, vertical: true)

								ForEach(BrailleRegistry.grade1ReferenceSections) { section in
									referenceSection(section)
								}

								ForEach(BrailleRegistry.grade2ReferenceSections) { section in
									referenceSection(section)
								}
							}
							.padding(.top, 8)
						},
						label: {
							Text("Braille Reference")
								.font(.headline)
								.foregroundStyle(AppTheme.heading)
								.accessibilityAddTraits(.isHeader)
						}
					)
					.tint(AppTheme.heading)
					.foregroundStyle(AppTheme.heading)
					.appCard()
				}
				.padding(24)
			}
			.scrollContentBackground(.hidden)
			.background(backgroundView)
			.navigationTitle("How to Play")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Back", action: dismissHowToPlay)
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
		VStack(alignment: .leading, spacing: 12) {
			Text(title)
				.font(.title3.weight(.bold))
				.foregroundStyle(AppTheme.heading)
				.accessibilityAddTraits(.isHeader)

			ForEach(rows, id: \.self) { row in
				Text(row)
					.foregroundStyle(secondaryTextColor)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.appCard()
	}

	private func inputInstructionSection(title: String, rows: [String]) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(title)
				.font(.title3.weight(.bold))
				.foregroundStyle(AppTheme.heading)
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
				.accessibilityElement(children: .combine)
			}
		}
	}

	private func referenceSection(_ section: BrailleRegistry.ReferenceSection) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(section.title)
				.font(.title3.weight(.bold))
				.foregroundStyle(AppTheme.heading)
				.accessibilityAddTraits(.isHeader)

			ForEach(section.rows) { row in
				VStack(alignment: .leading, spacing: 4) {
					Text(row.displayLabel)
						.font(.headline)
						.foregroundStyle(primaryTextColor)

					Text("Braille Dots: \(row.dotsText)")
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)

					Text("Braille Unicode: \(row.unicodeText)")
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(12)
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

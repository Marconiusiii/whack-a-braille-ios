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

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				Button("Back", action: dismissHowToPlay)
					.buttonStyle(SecondaryGameButton())

				VStack(alignment: .leading, spacing: 12) {
					Text("How to Play")
						.font(.system(.largeTitle, design: .rounded, weight: .heavy))
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
						"Invasion modes keep things wild by pulling from the full set each time a mole appears instead of sticking to five round favorites."
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

							inputInstructionSection(
								title: "Braille Display",
								rows: [
									"Use the 8-dot braille table for best results.",
									"Using Contracted or Uncontracted tables will require you to press Dot 8 or Space Bar to whack a mole after typing the right chord or character."
								]
							)

							inputInstructionSection(
								title: "Braille Screen Input",
								rows: [
									"Set the correct braille table before starting a round. Use Contracted for the Grade 2 moles, and Uncontracted for all the Grade 1 moles and typing modes.",
									"After typing the character or chord, swipe right with one or two fingers to whack the current mole.",
									"The moles stay up slightly longer in Braille Screen Input mode so you won't miss them when swiping right.",
									"Remember to turn off Braille Screen input once you are in the Round Results screen!"
								]
							)

							inputInstructionSection(
								title: "External Keyboard",
								rows: [
									"Type with the standard keyboard keys for Grade 1 and typing row input.",
									"Perkins Home Row is mapped as letters S, D, and F for dots 3, 2, and 1 respectively. J, K, and L are dots 4, 5, and 6 respectively.",
									"Perkins Home Row is defaulted to On for the Grade 2 modes."
								]
							)
						}
						.padding(.top, 8)
					},
					label: {
						Text("Input Instructions")
							.font(.headline)
							.foregroundStyle(AppTheme.heading)
					}
				)
				.tint(AppTheme.heading)
				.foregroundStyle(AppTheme.heading)
				.appCard()
			}
			.padding(24)
		}
		.appBackground()
		.accessibilityAction(.escape, dismissHowToPlay)
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

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}

	private func dismissHowToPlay() {
		onDismissRequest()
		dismiss()
	}
}

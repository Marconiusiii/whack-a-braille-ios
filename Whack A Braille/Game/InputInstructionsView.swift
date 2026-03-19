import SwiftUI

struct InputInstructionsView: View {

	let goBack: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@AccessibilityFocusState private var isHeadingFocused: Bool

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				Button("Back", action: goBack)
					.buttonStyle(SecondaryGameButton())

				VStack(alignment: .leading, spacing: 12) {
					Text("How to Whack Moles")
						.font(.system(.largeTitle, design: .rounded, weight: .heavy))
						.foregroundStyle(AppTheme.heading)
						.accessibilityAddTraits(.isHeader)
						.accessibilityFocused($isHeadingFocused)

					Text("You can use an external keyboard, a braille display, or braille screen input to whack the moles as they appear.")
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)
				}
				.appCard()

				VStack(alignment: .leading, spacing: 12) {
					Text("Braille Display")
						.font(.title3.weight(.bold))
						.foregroundStyle(AppTheme.heading)
						.accessibilityAddTraits(.isHeader)

					instructionRow("Use the 8-dot braille table for best results.")
					instructionRow("Using Contracted or Uncontracted tables will require you to press Dot 8 or Space Bar to whack a mole after typing the right chord or character.")
				}
				.appCard()

				VStack(alignment: .leading, spacing: 12) {
					Text("Braille Screen Input")
						.font(.title3.weight(.bold))
						.foregroundStyle(AppTheme.heading)
						.accessibilityAddTraits(.isHeader)

					instructionRow("Set the correct braille table before starting a round. Use Contracted for the Grade 2 moles, and Uncontracted for all the Grade 1 moles and typing modes.")
					instructionRow("After typing the character or chord, swipe right with one or two fingers to whack the current mole.")
					instructionRow("The moles stay up slightly longer in Braille Screen Input mode so you won't miss them when swiping right.")
					instructionRow("Remember to turn off Braille Screen input once you are in the Round Results screen!")
				}
				.appCard()

				VStack(alignment: .leading, spacing: 12) {
					Text("External Keyboard")
						.font(.title3.weight(.bold))
						.foregroundStyle(AppTheme.heading)
						.accessibilityAddTraits(.isHeader)

					instructionRow("Type with the standard keyboard keys for Grade 1 and typing row input.")
					instructionRow("Perkins Home Row is mapped as letters S, D, and F for dots 3, 2, and 1 respectively. J, K, and L are dots 4, 5, and 6 respectively.")
					instructionRow("Perkins Home Row is defaulted to On for the Grade 2 modes.")
				}
				.appCard()
			}
			.padding(24)
		}
		.appBackground()
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				isHeadingFocused = true
			}
		}
	}

	private func instructionRow(_ text: String) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Text("•")
				.foregroundStyle(AppTheme.heading)
			Text(text)
				.foregroundStyle(secondaryTextColor)
				.fixedSize(horizontal: false, vertical: true)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.accessibilityElement(children: .combine)
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}
}

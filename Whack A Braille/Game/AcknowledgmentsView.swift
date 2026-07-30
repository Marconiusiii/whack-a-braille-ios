import SwiftUI

struct AcknowledgmentsView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme
	@AccessibilityFocusState private var isHeadingFocused: Bool

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 0) {
					VStack(alignment: .leading, spacing: 12) {
						Text("Acknowledgments")
							.font(.system(.largeTitle, design: .rounded, weight: .heavy))
							.foregroundStyle(AppTheme.heading)
							.fixedSize(horizontal: false, vertical: true)
							.accessibilityAddTraits(.isHeader)
							.accessibilityFocused($isHeadingFocused)

						Text("Massive thanks to the developers and resources behind the English words used in Mole Battles and Wordy Mole Mayhem.")
							.foregroundStyle(secondaryTextColor)
							.fixedSize(horizontal: false, vertical: true)
					}
					.appCard()
					.accessibilityTouchRegion(minHeight: 0, topPadding: 24, bottomPadding: 10, horizontalPadding: 24, alignment: .leading)

					acknowledgmentDisclosure(
						title: "English Speller Database",
						rows: [
							"Word list copyright 2000-2026 by Kevin Atkinson.",
							"Permission to use, copy, modify, distribute, and sell any part of the English Speller Database (ESDB, previously known as SCOWLv2), or word lists created from it, is hereby granted without fee, provided that the above copyright notice appears in all copies and that both the above copyright notice and this notice appear in supporting documentation. Kevin Atkinson makes no representations about the suitability of this database for any purpose. It is provided \"as is\" without express or implied warranty.",
							"ESDB is derived from many sources, most of which are in the Public Domain. Data from the Corpus of Contemporary American English (COCA) was also used.",
							"The primary source of words for ESDB comes from 12dicts and ENABLE2K. Both are in the Public Domain, but Alan Beale deserves special credit as the author of 12dicts and a major contributor to ENABLE2K."
						],
						linkTitle: "Corpus of Contemporary American English",
						linkURL: "https://www.english-corpora.org/coca/"
					)

					acknowledgmentDisclosure(
						title: "Wordnik Wordlist",
						rows: [
							"The English word list also includes words from the Wordnik Wordlist, an open-source word list for game developers.",
							"Wordnik Wordlist copyright 2020 Wordnik. The Wordnik Wordlist is made available under the MIT License. Permission is granted, free of charge, to use, copy, modify, merge, publish, distribute, sublicense, and sell copies, provided that the copyright notice and permission notice are included in copies or substantial portions of the software."
						]
					)
				}
				.padding(.bottom, 24)
			}
			.appBackground()
			.navigationTitle("Acknowledgments")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") {
						dismiss()
					}
				}
			}
		}
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
				isHeadingFocused = true
			}
		}
	}

	private func acknowledgmentDisclosure(
		title: String,
		rows: [String],
		linkTitle: String? = nil,
		linkURL: String? = nil
	) -> some View {
		DisclosureGroup {
			VStack(alignment: .leading, spacing: 0) {
				ForEach(rows, id: \.self) { row in
					Text(row)
						.foregroundStyle(secondaryTextColor)
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityTouchRegion(minHeight: 0, verticalPadding: 8, alignment: .leading)
				}

				if let linkTitle, let linkURL, let url = URL(string: linkURL) {
					Link(linkTitle, destination: url)
						.foregroundStyle(AppTheme.heading)
						.underline()
						.accessibilityTouchRegion(minHeight: 54, alignment: .leading)
						.accessibilityHint("Opens in external browser")
				}
			}
		} label: {
			Text(title)
				.font(.headline)
				.foregroundStyle(AppTheme.heading)
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityTouchRegion(minHeight: 0, topPadding: 20, bottomPadding: 8, alignment: .leading)
				.accessibilityAddTraits(.isHeader)
		}
		.tint(AppTheme.heading)
		.appActionCard()
	}

	private var secondaryTextColor: Color {
		colorScheme == .dark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText
	}
}

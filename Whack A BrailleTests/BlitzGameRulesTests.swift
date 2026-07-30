import Foundation

@main
enum BlitzGameRulesTests {
	static func main() throws {
		let catalogURL = URL(fileURLWithPath: CommandLine.arguments[1])
		let sourceURL = URL(fileURLWithPath: CommandLine.arguments[2])
		let wordyMoleMayhemCatalogURL = URL(fileURLWithPath: CommandLine.arguments[3])
		let wordyMoleMayhemExclusionsURL = URL(fileURLWithPath: CommandLine.arguments[4])
		let wordyMoleMayhemCommonWordsURL = URL(fileURLWithPath: CommandLine.arguments[5])
		let catalogContents = try String(contentsOf: catalogURL, encoding: .utf8)
		let sourceWords = Set(
			try String(contentsOf: sourceURL, encoding: .utf8)
				.components(separatedBy: .newlines)
		)
		let wordyMoleMayhemCatalogContents = try String(contentsOf: wordyMoleMayhemCatalogURL, encoding: .utf8)
		let excludedWordyMoleMayhemWords = Set(
			try String(contentsOf: wordyMoleMayhemExclusionsURL, encoding: .utf8)
				.components(separatedBy: .newlines)
				.filter { !$0.isEmpty && !$0.hasPrefix("#") }
		)
		let commonWordyMoleMayhemWords = Set(
			try String(contentsOf: wordyMoleMayhemCommonWordsURL, encoding: .utf8)
				.components(separatedBy: .newlines)
				.filter { !$0.isEmpty && !$0.hasPrefix("#") }
		)
		let words = BlitzWordCatalog.words(from: catalogContents)
		let issues = BlitzWordCatalog.validationIssues(in: words)
		let wordyMoleMayhemEntries = WordyMoleMayhemCatalog.entries(from: wordyMoleMayhemCatalogContents)
		let wordyMoleMayhemIssues = WordyMoleMayhemCatalog.validationIssues(in: wordyMoleMayhemEntries)

		precondition(issues.isEmpty, issues.joined(separator: "\n"))
		precondition(wordyMoleMayhemIssues.isEmpty, wordyMoleMayhemIssues.joined(separator: "\n"))
		precondition(words.allSatisfy { sourceWords.contains($0.text) })
		precondition(wordyMoleMayhemEntries.count > 20_000)
		precondition(wordyMoleMayhemEntries.allSatisfy { sourceWords.contains($0.text) })
		precondition(wordyMoleMayhemEntries.allSatisfy { commonWordyMoleMayhemWords.contains($0.text) })
		precondition(wordyMoleMayhemEntries.allSatisfy { !excludedWordyMoleMayhemWords.contains($0.text) })
		let customWords = words.map(\.text)
		precondition(BlitzWordCatalog.words(for: "grade1ThreeLetterBlitz", customWords: customWords).allSatisfy { $0.length == 3 })
		precondition(BlitzWordCatalog.words(for: "grade1FourLetterBlitz", customWords: customWords).allSatisfy { $0.length == 4 })
		precondition(BlitzWord.allowedLengths(for: "grade1MoleBlitz") == [3, 4, 5])
		precondition((0..<3).map { BlitzWord.pan(forLetterAt: $0, wordLength: 3) } == [-0.5, 0, 0.5])
		precondition((0..<4).map { BlitzWord.pan(forLetterAt: $0, wordLength: 4) } == [-0.75, -0.25, 0.25, 0.75])
		precondition((0..<5).map { BlitzWord.pan(forLetterAt: $0, wordLength: 5) } == [-1, -0.5, 0, 0.5, 1])
		let repeatedLetterItem = BlitzWord(text: "book").asBrailleItem(modeId: "grade1FourLetterBlitz")
		precondition(repeatedLetterItem?.perkinsSequenceDots.count == 4)
		precondition(repeatedLetterItem?.perkinsSequenceDots[1] == repeatedLetterItem?.perkinsSequenceDots[2])
		precondition(repeatedLetterItem?.modeTags == ["grade1FourLetterBlitz"])

		let knowledge = wordyMoleMayhemEntries.first { $0.text == "knowledge" }
		precondition(knowledge?.contractedMasks.count == 1)
		precondition(knowledge?.acceptedPerkinsSequences.contains(knowledge?.contractedMasks ?? []) == true)
		precondition(knowledge?.acceptedPerkinsSequences.contains(knowledge?.uncontractedMasks ?? []) == true)
		precondition(knowledge?.asBrailleItem()?.acceptedTextInputs == ["knowledge"])

		let qwertySections = BrailleRegistry.filteredModeSections(for: .qwerty)
		precondition(qwertySections.map(\.title) == ["Grade 1", "Grade 2", "Mole Battles", "Typing", "Custom"])
		precondition(qwertySections.first(where: { $0.id == "typing" })?.options.map(\.label) == [
			"Simple Home Row",
			"QWERTY Home Row",
			"QWERTY Home Row + Top Row",
			"QWERTY Home Row + Bottom Row"
		])
		precondition(qwertySections.first(where: { $0.id == "moleBattles" })?.options.map(\.label) == [
			"3-Letter Words",
			"4-Letter Words",
			"Grade 1 Mole Battle",
			"Wordy Mole Mayhem"
		])
		precondition(BrailleRegistry.sanitizedModeId("holyMoleyWordWar", for: .qwerty) == WordyMoleMayhemCatalog.modeId)
		precondition(qwertySections.first(where: { $0.id == "grade2" })?.options.contains(where: { $0.id == "grade2Suffixes" }) == true)
		precondition(qwertySections.first(where: { $0.id == "grade2" })?.options.contains(where: { $0.id == "grade2Dot456Initials" }) == false)

		let perkinsSections = BrailleRegistry.filteredModeSections(for: .perkins)
		precondition(perkinsSections.contains(where: { $0.id == "typing" }) == false)
		precondition(perkinsSections.first(where: { $0.id == "grade2" })?.options.contains(where: { $0.id == "grade2Suffixes" }) == true)
		precondition(perkinsSections.first(where: { $0.id == "grade2" })?.options.contains(where: { $0.id == "grade2Dot456Initials" }) == true)

		let brailleScreenSections = BrailleRegistry.filteredModeSections(for: .brailleText)
		precondition(brailleScreenSections.contains(where: { $0.id == "typing" }) == false)
		precondition(brailleScreenSections.first(where: { $0.id == "grade2" })?.options.contains(where: { $0.id == "grade2Suffixes" }) == false)

		let counts = Dictionary(grouping: words, by: \.length).mapValues(\.count)
		let wordyMoleMayhemCounts = Dictionary(grouping: wordyMoleMayhemEntries, by: \.length).mapValues(\.count)
		precondition((4...10).allSatisfy { wordyMoleMayhemCounts[$0, default: 0] > 1_000 })
		print("Mole Battle catalog validated: \(words.count) words; 3-letter \(counts[3, default: 0]), 4-letter \(counts[4, default: 0]), 5-letter \(counts[5, default: 0]).")
		print("Wordy Mole Mayhem catalog validated: \(wordyMoleMayhemEntries.count) words; lengths \(wordyMoleMayhemCounts.sorted { $0.key < $1.key }).")
	}
}

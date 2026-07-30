import Foundation

@main
enum BlitzGameRulesTests {
	static func main() throws {
		let catalogURL = URL(fileURLWithPath: CommandLine.arguments[1])
		let sourceURL = URL(fileURLWithPath: CommandLine.arguments[2])
		let catalogContents = try String(contentsOf: catalogURL, encoding: .utf8)
		let sourceWords = Set(
			try String(contentsOf: sourceURL, encoding: .utf8)
				.components(separatedBy: .newlines)
		)
		let words = BlitzWordCatalog.words(from: catalogContents)
		let issues = BlitzWordCatalog.validationIssues(in: words)

		precondition(issues.isEmpty, issues.joined(separator: "\n"))
		precondition(words.allSatisfy { sourceWords.contains($0.text) })
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

		let counts = Dictionary(grouping: words, by: \.length).mapValues(\.count)
		print("Blitz catalog validated: \(words.count) words; 3-letter \(counts[3, default: 0]), 4-letter \(counts[4, default: 0]), 5-letter \(counts[5, default: 0]).")
	}
}

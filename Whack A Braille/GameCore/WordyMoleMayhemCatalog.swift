import Foundation

struct WordyMoleMayhemEntry: Identifiable, Hashable {
	let text: String
	let contractedMasks: [Int]

	var id: String { text }
	var length: Int { text.count }

	var uncontractedMasks: [Int] {
		let masksByLetter = Dictionary(
			uniqueKeysWithValues: BrailleRegistry.grade1Letters.map { ($0.id, $0.dotMask) }
		)
		return text.compactMap { masksByLetter[String($0)] }
	}

	var acceptedPerkinsSequences: [[Int]] {
		var sequences = [contractedMasks]
		let uncontracted = uncontractedMasks
		if uncontracted != contractedMasks {
			sequences.append(uncontracted)
		}
		return sequences
	}

	func asBrailleItem() -> BrailleItem? {
		guard let finalMask = contractedMasks.last else { return nil }
		let contractedDots = contractedMasks.map(Self.dots(for:))

		return BrailleItem(
			id: text,
			displayLabel: text,
			announceText: text,
			dots: Self.dots(for: finalMask),
			dotMask: finalMask,
			perkinsKeys: [],
			perkinsSequenceDots: contractedDots,
			perkinsSequenceMasks: contractedMasks,
			acceptedPerkinsSequences: acceptedPerkinsSequences,
			expectedPerkinsCellCount: contractedMasks.count,
			standardKey: nil,
			acceptedTextInputs: [text],
			textInputTokenSequences: [text.map(String.init)],
			modeTags: [WordyMoleMayhemCatalog.modeId],
			nato: nil
		)
	}

	nonisolated private static func dots(for mask: Int) -> [Int] {
		(1...8).filter { mask & (1 << ($0 - 1)) != 0 }
	}

	nonisolated static func dotsForSpeech(for mask: Int) -> [Int] {
		dots(for: mask)
	}
}

enum WordyMoleMayhemCatalog {
	nonisolated static let modeId = "wordyMoleMayhem"
	private static let resourceName = "wordy-mole-mayhem-words-en"

	static let all: [WordyMoleMayhemEntry] = loadEntries()
	private static let entriesByText: [String: WordyMoleMayhemEntry] = Dictionary(
		uniqueKeysWithValues: all.map { ($0.text, $0) }
	)

	static func words(for modeId: String, customWords: [String] = []) -> [WordyMoleMayhemEntry] {
		guard modeId == self.modeId else { return [] }
		guard !customWords.isEmpty else { return all }
		return normalizedWords(customWords).compactMap { entriesByText[$0] }
	}

	static func entries(from contents: String) -> [WordyMoleMayhemEntry] {
		var seen = Set<String>()

		return contents.components(separatedBy: .newlines).compactMap { line in
			let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
			guard fields.count == 2 else { return nil }

			let word = String(fields[0]).lowercased()
			guard (4...10).contains(word.count),
				word.allSatisfy({ $0.isASCII && $0.isLowercase && $0.isLetter }),
				seen.insert(word).inserted
			else { return nil }

			let masks = fields[1]
				.split(separator: ",")
				.compactMap { Int($0) }
			guard !masks.isEmpty, masks.allSatisfy({ (1...255).contains($0) }) else { return nil }

			return WordyMoleMayhemEntry(text: word, contractedMasks: masks)
		}
	}

	static func validationIssues(in entries: [WordyMoleMayhemEntry] = all) -> [String] {
		var issues: [String] = []
		let words = entries.map(\.text)

		if entries.isEmpty {
			issues.append("The Wordy Mole Mayhem catalog is empty.")
		}
		if Set(words).count != words.count {
			issues.append("The Wordy Mole Mayhem catalog contains duplicate words.")
		}
		if let invalid = entries.first(where: { !(4...10).contains($0.length) }) {
			issues.append("Invalid Wordy Mole Mayhem word length: \(invalid.text)")
		}
		if let invalid = entries.first(where: {
			!$0.text.allSatisfy { $0.isASCII && $0.isLowercase && $0.isLetter }
		}) {
			issues.append("Invalid Wordy Mole Mayhem characters: \(invalid.text)")
		}
		if let invalid = entries.first(where: {
			$0.contractedMasks.isEmpty || !$0.contractedMasks.allSatisfy { (1...255).contains($0) }
		}) {
			issues.append("Invalid Wordy Mole Mayhem UEB cells: \(invalid.text)")
		}
		for length in 4...10 where !entries.contains(where: { $0.length == length }) {
			issues.append("The Wordy Mole Mayhem catalog has no \(length)-letter words.")
		}

		return issues
	}

	private static func loadEntries() -> [WordyMoleMayhemEntry] {
		let url = Bundle.main.url(
			forResource: resourceName,
			withExtension: "tsv",
			subdirectory: "Resources"
		) ?? Bundle.main.url(forResource: resourceName, withExtension: "tsv")

		guard let url, let contents = try? String(contentsOf: url, encoding: .utf8) else {
			return []
		}
		return entries(from: contents)
	}

	private static func normalizedWords(_ values: [String]) -> [String] {
		var seen = Set<String>()
		return values.compactMap { value in
			let word = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			guard seen.insert(word).inserted else { return nil }
			return word
		}
	}
}

import Foundation

enum BlitzWordCatalog {
	private static let resourceName = "blitz-words-en"

	static let all: [BlitzWord] = loadWords()

	static func words(for modeId: String, customWords: [String] = []) -> [BlitzWord] {
		let allowedLengths = BlitzWord.allowedLengths(for: modeId)
		guard !allowedLengths.isEmpty else { return [] }

		if !customWords.isEmpty {
			return normalizedWords(customWords)
				.filter { allowedLengths.contains($0.length) }
		}

		return all.filter { allowedLengths.contains($0.length) }
	}

	static func validationIssues(in words: [BlitzWord] = all) -> [String] {
		var issues: [String] = []
		let texts = words.map(\.text)

		if words.isEmpty {
			issues.append("The Blitz word catalog is empty.")
		}

		if Set(texts).count != texts.count {
			issues.append("The Blitz word catalog contains duplicate words.")
		}

		if let invalid = words.first(where: { !(3...5).contains($0.length) }) {
			issues.append("Invalid Blitz word length: \(invalid.text)")
		}

		if let invalid = words.first(where: { !$0.text.allSatisfy { $0.isASCII && $0.isLowercase && $0.isLetter } }) {
			issues.append("Invalid Blitz word characters: \(invalid.text)")
		}

		for length in 3...5 where !words.contains(where: { $0.length == length }) {
			issues.append("The Blitz word catalog has no \(length)-letter words.")
		}

		return issues
	}

	static func words(from contents: String) -> [BlitzWord] {
		normalizedWords(contents.components(separatedBy: .newlines))
	}

	private static func loadWords() -> [BlitzWord] {
		let url = Bundle.main.url(forResource: resourceName, withExtension: "txt", subdirectory: "Resources")
			?? Bundle.main.url(forResource: resourceName, withExtension: "txt")

		guard let url, let contents = try? String(contentsOf: url, encoding: .utf8) else {
			return []
		}

		return words(from: contents)
	}

	private static func normalizedWords(_ values: [String]) -> [BlitzWord] {
		var seen = Set<String>()
		return values.compactMap { value in
			let word = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			guard (3...5).contains(word.count) else { return nil }
			guard word.allSatisfy({ $0.isASCII && $0.isLowercase && $0.isLetter }) else { return nil }
			guard seen.insert(word).inserted else { return nil }
			return BlitzWord(text: word)
		}
	}
}

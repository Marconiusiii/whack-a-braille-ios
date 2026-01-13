import Foundation

enum BrailleRegistry {

	// MARK: - Helpers

	private static func dotsToMask(_ dots: [Int]) -> Int {
		var mask = 0
		for dot in dots {
			mask |= 1 << (dot - 1)
		}
		return mask
	}

	private static func dotsToPerkinsKeys(_ dots: [Int]) -> [String] {
		let map: [Int: String] = [
			1: "f",
			2: "d",
			3: "s",
			4: "j",
			5: "k",
			6: "l"
		]
		return dots.compactMap { map[$0] }
	}

	private static func makeItem(
		id: String,
		announce: String,
		dots: [Int],
		modes: [String],
		standardKey: String? = nil
	) -> BrailleItem {
		return BrailleItem(
			id: id,
			announceText: announce,
			dots: dots,
			dotMask: dotsToMask(dots),
			perkinsKeys: dotsToPerkinsKeys(dots),
			standardKey: standardKey,
			modeTags: Set(modes)
		)
	}

	// MARK: - Grade 1 Letters

	static let grade1Letters: [BrailleItem] = [
		makeItem(id: "a", announce: "a", dots: [1], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "a"),
		makeItem(id: "b", announce: "b", dots: [1,2], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "b"),
		makeItem(id: "c", announce: "c", dots: [1,4], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "c"),
		makeItem(id: "d", announce: "d", dots: [1,4,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "d"),
		makeItem(id: "e", announce: "e", dots: [1,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "e"),
		makeItem(id: "f", announce: "f", dots: [1,2,4], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "f"),
		makeItem(id: "g", announce: "g", dots: [1,2,4,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "g"),
		makeItem(id: "h", announce: "h", dots: [1,2,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "h"),
		makeItem(id: "i", announce: "i", dots: [2,4], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "i"),
		makeItem(id: "j", announce: "j", dots: [2,4,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "j"),
		makeItem(id: "k", announce: "k", dots: [1,3], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "k"),
		makeItem(id: "l", announce: "l", dots: [1,2,3], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "l"),
		makeItem(id: "m", announce: "m", dots: [1,3,4], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "m"),
		makeItem(id: "n", announce: "n", dots: [1,3,4,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "n"),
		makeItem(id: "o", announce: "o", dots: [1,3,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "o"),
		makeItem(id: "p", announce: "p", dots: [1,2,3,4], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "p"),
		makeItem(id: "q", announce: "q", dots: [1,2,3,4,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "q"),
		makeItem(id: "r", announce: "r", dots: [1,2,3,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "r"),
		makeItem(id: "s", announce: "s", dots: [2,3,4], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "s"),
		makeItem(id: "t", announce: "t", dots: [2,3,4,5], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "t"),
		makeItem(id: "u", announce: "u", dots: [1,3,6], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "u"),
		makeItem(id: "v", announce: "v", dots: [1,2,3,6], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "v"),
		makeItem(id: "w", announce: "w", dots: [2,4,5,6], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "w"),
		makeItem(id: "x", announce: "x", dots: [1,3,4,6], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "x"),
		makeItem(id: "y", announce: "y", dots: [1,3,4,5,6], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "y"),
		makeItem(id: "z", announce: "z", dots: [1,3,5,6], modes: ["grade1Letters","grade1LettersNumbers"], standardKey: "z")
	]

	// MARK: - Grade 1 Numbers

	static let grade1Numbers: [BrailleItem] = [
		makeItem(id: "1", announce: "1", dots: [1], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "1"),
		makeItem(id: "2", announce: "2", dots: [1,2], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "2"),
		makeItem(id: "3", announce: "3", dots: [1,4], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "3"),
		makeItem(id: "4", announce: "4", dots: [1,4,5], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "4"),
		makeItem(id: "5", announce: "5", dots: [1,5], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "5"),
		makeItem(id: "6", announce: "6", dots: [1,2,4], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "6"),
		makeItem(id: "7", announce: "7", dots: [1,2,4,5], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "7"),
		makeItem(id: "8", announce: "8", dots: [1,2,5], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "8"),
		makeItem(id: "9", announce: "9", dots: [2,4], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "9"),
		makeItem(id: "0", announce: "0", dots: [2,4,5], modes: ["grade1Numbers","grade1LettersNumbers"], standardKey: "0")
	]

	static let grade2Symbols: [BrailleItem] = [
		makeItem(id: "er", announce: "E R", dots: [1,2,4,5,6], modes: ["grade2Symbols"]),
		makeItem(id: "ed", announce: "E D", dots: [1,2,4,6], modes: ["grade2Symbols"]),
		makeItem(id: "gh", announce: "G H", dots: [1,2,6], modes: ["grade2Symbols"]),
		makeItem(id: "ar", announce: "A R", dots: [3,4,5], modes: ["grade2Symbols"]),
		makeItem(id: "ow", announce: "O W", dots: [2,4,6], modes: ["grade2Symbols"]),
		makeItem(id: "ou", announce: "O U", dots: [1,2,5,6], modes: ["grade2Symbols"]),
		makeItem(id: "st", announce: "S T", dots: [3,4], modes: ["grade2Symbols"]),
		makeItem(id: "ch", announce: "C H", dots: [1,6], modes: ["grade2Symbols"]),
		makeItem(id: "wh", announce: "W H", dots: [1,5,6], modes: ["grade2Symbols"]),
		makeItem(id: "ing", announce: "I N G", dots: [3,4,6], modes: ["grade2Symbols"]),
		makeItem(id: "dis", announce: "dis", dots: [2,5,6], modes: ["grade2Symbols"]),
		makeItem(id: "con", announce: "con", dots: [2,5], modes: ["grade2Symbols"]),
		makeItem(id: "of", announce: "of", dots: [1,2,3,5,6], modes: ["grade2Symbols"]),
		makeItem(id: "with", announce: "with", dots: [2,3,4,5,6], modes: ["grade2Symbols"]),
		makeItem(id: "and", announce: "and", dots: [1,2,3,4,6], modes: ["grade2Symbols"]),
		makeItem(id: "for", announce: "for", dots: [1,2,3,4,5,6], modes: ["grade2Symbols"]),
		makeItem(id: "the", announce: "the", dots: [2,3,4,6], modes: ["grade2Symbols"])
	]

	static let grade2Words: [BrailleItem] = [
		makeItem(id: "but", announce: "but", dots: [1,2], modes: ["grade2Words"]),
		makeItem(id: "can", announce: "can", dots: [1,4], modes: ["grade2Words"]),
		makeItem(id: "do", announce: "do", dots: [1,4,5], modes: ["grade2Words"]),
		makeItem(id: "every", announce: "every", dots: [1,5], modes: ["grade2Words"]),
		makeItem(id: "from", announce: "from", dots: [1,2,4], modes: ["grade2Words"]),
		makeItem(id: "go", announce: "go", dots: [1,2,4,5], modes: ["grade2Words"]),
		makeItem(id: "have", announce: "have", dots: [1,2,5], modes: ["grade2Words"]),
		makeItem(id: "just", announce: "just", dots: [2,4,5], modes: ["grade2Words"]),
		makeItem(id: "knowledge", announce: "knowledge", dots: [1,3], modes: ["grade2Words"]),
		makeItem(id: "like", announce: "like", dots: [1,2,3], modes: ["grade2Words"]),
		makeItem(id: "more", announce: "more", dots: [1,3,4], modes: ["grade2Words"]),
		makeItem(id: "not", announce: "not", dots: [1,3,4,5], modes: ["grade2Words"]),
		makeItem(id: "people", announce: "people", dots: [1,2,3,4], modes: ["grade2Words"]),
		makeItem(id: "quite", announce: "quite", dots: [1,2,3,4,5], modes: ["grade2Words"]),
		makeItem(id: "rather", announce: "rather", dots: [1,2,3,5], modes: ["grade2Words"]),
		makeItem(id: "so", announce: "so", dots: [2,3,4], modes: ["grade2Words"]),
		makeItem(id: "that", announce: "that", dots: [2,3,4,5], modes: ["grade2Words"]),
		makeItem(id: "us", announce: "us", dots: [1,3,6], modes: ["grade2Words"]),
		makeItem(id: "very", announce: "very", dots: [1,2,3,6], modes: ["grade2Words"]),
		makeItem(id: "will", announce: "will", dots: [2,4,5,6], modes: ["grade2Words"]),
		makeItem(id: "it", announce: "it", dots: [1,3,4,6], modes: ["grade2Words"]),
		makeItem(id: "you", announce: "you", dots: [1,3,4,5,6], modes: ["grade2Words"]),
		makeItem(id: "as", announce: "as", dots: [1,3,5,6], modes: ["grade2Words"]),
		makeItem(id: "this", announce: "this", dots: [1,4,5,6], modes: ["grade2Words"]),
		makeItem(id: "which", announce: "which", dots: [1,5,6], modes: ["grade2Words"]),
		makeItem(id: "child", announce: "child", dots: [1,6], modes: ["grade2Words"]),
		makeItem(id: "shall", announce: "shall", dots: [1,4,6], modes: ["grade2Words"])
	]

	// MARK: - Combined access

	static let allItems: [BrailleItem] =
		grade1Letters +
		grade1Numbers +
		grade2Symbols +
		grade2Words

	static func getItems(for modeId: String) -> [BrailleItem] {
		switch modeId {
		case "grade1LettersNumbers":
			return grade1Letters + grade1Numbers
		case "grade2Symbols":
			return grade2Symbols
		case "grade2Words":
			return grade2Words
		case "everything":
			return allItems
		default:
			return grade1Letters + grade1Numbers
		}
	}
}

import Foundation

enum CustomMolePlayMode: String, CaseIterable, Identifiable {
	case individual
	case invasion

	var id: String { rawValue }

	var label: String {
		switch self {
		case .individual:
			return "Individual Moles"
		case .invasion:
			return "Invasion Army"
		}
	}
}

enum BrailleRegistry {

	typealias ModeOption = (id: String, label: String)

	struct ModeSection: Identifiable {
		let id: String
		let title: String
		let options: [ModeOption]
	}

	struct CustomMoleSection: Identifiable {
		let id: String
		let title: String
		let items: [BrailleItem]
	}

	struct ReferenceRow: Identifiable {
		let id: String
		let displayLabel: String
		let dotsText: String
		let unicodeText: String
	}

	struct ReferenceSection: Identifiable {
		let id: String
		let title: String
		let rows: [ReferenceRow]
	}

	private nonisolated static let braillePatternBase = 0x2800

	private nonisolated static func dotsToMask(_ dots: [Int]) -> Int {
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

	private static func normalizePerkinsSequence(_ rawSequence: [[Int]]?, fallbackDots: [Int]) -> [[Int]] {
		let source = (rawSequence?.isEmpty == false) ? rawSequence! : [fallbackDots]
		return source.map { $0.sorted() }
	}

	private static func normalizeTokens(_ tokens: [String]) -> [String] {
		tokens
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
			.filter { !$0.isEmpty }
	}

	private static func dedupeInputs(_ inputs: [String]) -> [String] {
		var seen = Set<String>()
		var result: [String] = []

		for input in normalizeTokens(inputs) where seen.insert(input).inserted {
			result.append(input)
		}

		return result
	}

	private static func dedupeTokenSequences(_ sequences: [[String]]) -> [[String]] {
		var seen = Set<String>()
		var result: [[String]] = []

		for sequence in sequences {
			let normalized = normalizeTokens(sequence)
			guard !normalized.isEmpty else { continue }
			let key = normalized.joined(separator: "\u{1F}")
			guard seen.insert(key).inserted else { continue }
			result.append(normalized)
		}

		return result
	}

	private static func makeItem(
		id: String,
		announce: String,
		dots: [Int],
		modes: [String],
		standardKey: String? = nil,
		acceptedInputs: [String] = [],
		textTokenSequences: [[String]]? = nil,
		perkinsSequence: [[Int]]? = nil,
		nato: String? = nil
	) -> BrailleItem {
		var acceptedTextInputs = [id]
		if let standardKey {
			acceptedTextInputs.append(standardKey)
		}
		acceptedTextInputs.append(contentsOf: acceptedInputs)

		let normalizedAcceptedInputs = dedupeInputs(acceptedTextInputs)
		let normalizedPerkinsSequence = normalizePerkinsSequence(perkinsSequence, fallbackDots: dots)
		let normalizedTokenSequences = dedupeTokenSequences(
			textTokenSequences ?? normalizedAcceptedInputs.map { [$0] }
		)

		return BrailleItem(
			id: id,
			displayLabel: id,
			announceText: announce,
			dots: dots,
			dotMask: dotsToMask(dots),
			perkinsKeys: dotsToPerkinsKeys(dots),
			perkinsSequenceDots: normalizedPerkinsSequence,
			perkinsSequenceMasks: normalizedPerkinsSequence.map(dotsToMask),
			acceptedPerkinsSequences: [normalizedPerkinsSequence.map(dotsToMask)],
			expectedPerkinsCellCount: normalizedPerkinsSequence.count,
			standardKey: standardKey,
			acceptedTextInputs: normalizedAcceptedInputs,
			textInputTokenSequences: normalizedTokenSequences,
			modeTags: Set(modes),
			nato: nato
		)
	}

	private static func makeTypingItem(
		key: String,
		announce: String,
		modes: [String]
	) -> BrailleItem {
		BrailleItem(
			id: key,
			displayLabel: key,
			announceText: announce,
			dots: [],
			dotMask: 0,
			perkinsKeys: [],
			perkinsSequenceDots: [],
			perkinsSequenceMasks: [],
			acceptedPerkinsSequences: [],
			expectedPerkinsCellCount: 1,
			standardKey: key,
			acceptedTextInputs: [key],
			textInputTokenSequences: [[key.lowercased()]],
			modeTags: Set(modes),
			nato: nil
		)
	}

	private static func makeSequenceItem(
		id: String,
		announce: String,
		sequenceDots: [[Int]],
		modes: [String],
		acceptedInputs: [String] = [],
		textTokenSequences: [[String]] = []
	) -> BrailleItem {
		let finalDots = sequenceDots.last ?? []
		return makeItem(
			id: id,
			announce: announce,
			dots: finalDots,
			modes: modes,
			acceptedInputs: acceptedInputs,
			textTokenSequences: textTokenSequences,
			perkinsSequence: sequenceDots
		)
	}

	private nonisolated static func brailleUnicode(for dots: [Int]) -> String {
		let mask = dotsToMask(dots)
		guard let scalar = UnicodeScalar(braillePatternBase + mask) else { return "" }
		return String(Character(scalar))
	}

	private static func dotsText(for sequence: [[Int]]) -> String {
		sequence
			.map { step in step.map(String.init).joined(separator: " ") }
			.joined(separator: ", ")
	}

	private static func unicodeText(for sequence: [[Int]]) -> String {
		sequence
			.map(brailleUnicode(for:))
			.joined()
	}

	private static func referenceRows(for items: [BrailleItem]) -> [ReferenceRow] {
		items.map { item in
			ReferenceRow(
				id: item.id,
				displayLabel: item.displayLabel,
				dotsText: dotsText(for: item.perkinsSequenceDots.isEmpty ? [item.dots] : item.perkinsSequenceDots),
				unicodeText: unicodeText(for: item.perkinsSequenceDots.isEmpty ? [item.dots] : item.perkinsSequenceDots)
			)
		}
	}

	static let grade1Letters: [BrailleItem] = [
		makeItem(id: "a", announce: "a", dots: [1], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "a", nato: "Alpha"),
		makeItem(id: "b", announce: "b", dots: [1, 2], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "b", nato: "Bravo"),
		makeItem(id: "c", announce: "c", dots: [1, 4], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "c", nato: "Charlie"),
		makeItem(id: "d", announce: "d", dots: [1, 4, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "d", nato: "Delta"),
		makeItem(id: "e", announce: "e", dots: [1, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "e", nato: "Echo"),
		makeItem(id: "f", announce: "f", dots: [1, 2, 4], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "f", nato: "Foxtrot"),
		makeItem(id: "g", announce: "g", dots: [1, 2, 4, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "g", nato: "Golf"),
		makeItem(id: "h", announce: "h", dots: [1, 2, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "h", nato: "Hotel"),
		makeItem(id: "i", announce: "i", dots: [2, 4], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "i", nato: "India"),
		makeItem(id: "j", announce: "j", dots: [2, 4, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "j", nato: "Juliet"),
		makeItem(id: "k", announce: "k", dots: [1, 3], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "k", nato: "Kilo"),
		makeItem(id: "l", announce: "l", dots: [1, 2, 3], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "l", nato: "Lima"),
		makeItem(id: "m", announce: "m", dots: [1, 3, 4], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "m", nato: "Mike"),
		makeItem(id: "n", announce: "n", dots: [1, 3, 4, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "n", nato: "November"),
		makeItem(id: "o", announce: "o", dots: [1, 3, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "o", nato: "Oscar"),
		makeItem(id: "p", announce: "p", dots: [1, 2, 3, 4], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "p", nato: "Papa"),
		makeItem(id: "q", announce: "q", dots: [1, 2, 3, 4, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "q", nato: "Quebec"),
		makeItem(id: "r", announce: "r", dots: [1, 2, 3, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "r", nato: "Romeo"),
		makeItem(id: "s", announce: "s", dots: [2, 3, 4], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "s", nato: "Sierra"),
		makeItem(id: "t", announce: "t", dots: [2, 3, 4, 5], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "t", nato: "Tango"),
		makeItem(id: "u", announce: "u", dots: [1, 3, 6], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "u", nato: "Uniform"),
		makeItem(id: "v", announce: "v", dots: [1, 2, 3, 6], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "v", nato: "Victor"),
		makeItem(id: "w", announce: "w", dots: [2, 4, 5, 6], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "w", nato: "Whiskey"),
		makeItem(id: "x", announce: "x", dots: [1, 3, 4, 6], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "x", nato: "X-ray"),
		makeItem(id: "y", announce: "y", dots: [1, 3, 4, 5, 6], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "y", nato: "Yankee"),
		makeItem(id: "z", announce: "z", dots: [1, 3, 5, 6], modes: ["grade1Letters", "grade1LettersNumbers"], standardKey: "z", nato: "Zulu")
	]

	static let grade1Numbers: [BrailleItem] = [
		makeItem(id: "1", announce: "1", dots: [1], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "1", acceptedInputs: ["#a"], textTokenSequences: [["1"], ["#", "a"]], perkinsSequence: [[3, 4, 5, 6], [1]]),
		makeItem(id: "2", announce: "2", dots: [1, 2], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "2", acceptedInputs: ["#b"], textTokenSequences: [["2"], ["#", "b"]], perkinsSequence: [[3, 4, 5, 6], [1, 2]]),
		makeItem(id: "3", announce: "3", dots: [1, 4], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "3", acceptedInputs: ["#c"], textTokenSequences: [["3"], ["#", "c"]], perkinsSequence: [[3, 4, 5, 6], [1, 4]]),
		makeItem(id: "4", announce: "4", dots: [1, 4, 5], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "4", acceptedInputs: ["#d"], textTokenSequences: [["4"], ["#", "d"]], perkinsSequence: [[3, 4, 5, 6], [1, 4, 5]]),
		makeItem(id: "5", announce: "5", dots: [1, 5], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "5", acceptedInputs: ["#e"], textTokenSequences: [["5"], ["#", "e"]], perkinsSequence: [[3, 4, 5, 6], [1, 5]]),
		makeItem(id: "6", announce: "6", dots: [1, 2, 4], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "6", acceptedInputs: ["#f"], textTokenSequences: [["6"], ["#", "f"]], perkinsSequence: [[3, 4, 5, 6], [1, 2, 4]]),
		makeItem(id: "7", announce: "7", dots: [1, 2, 4, 5], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "7", acceptedInputs: ["#g"], textTokenSequences: [["7"], ["#", "g"]], perkinsSequence: [[3, 4, 5, 6], [1, 2, 4, 5]]),
		makeItem(id: "8", announce: "8", dots: [1, 2, 5], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "8", acceptedInputs: ["#h"], textTokenSequences: [["8"], ["#", "h"]], perkinsSequence: [[3, 4, 5, 6], [1, 2, 5]]),
		makeItem(id: "9", announce: "9", dots: [2, 4], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "9", acceptedInputs: ["#i"], textTokenSequences: [["9"], ["#", "i"]], perkinsSequence: [[3, 4, 5, 6], [2, 4]]),
		makeItem(id: "0", announce: "0", dots: [2, 4, 5], modes: ["grade1Numbers", "grade1LettersNumbers"], standardKey: "0", acceptedInputs: ["#j"], textTokenSequences: [["0"], ["#", "j"]], perkinsSequence: [[3, 4, 5, 6], [2, 4, 5]])
	]

	static let grade2Symbols: [BrailleItem] = [
		makeItem(id: "er", announce: "E R", dots: [1, 2, 4, 5, 6], modes: ["grade2Symbols"], acceptedInputs: ["}"]),
		makeItem(id: "ed", announce: "E D", dots: [1, 2, 4, 6], modes: ["grade2Symbols"], acceptedInputs: ["$"]),
		makeItem(id: "gh", announce: "G H", dots: [1, 2, 6], modes: ["grade2Symbols"], acceptedInputs: ["<"]),
		makeItem(id: "ar", announce: "A R", dots: [3, 4, 5], modes: ["grade2Symbols"], acceptedInputs: [">"]),
		makeItem(id: "ow", announce: "O W", dots: [2, 4, 6], modes: ["grade2Symbols"], acceptedInputs: ["{"]),
		makeItem(id: "ou", announce: "O U", dots: [1, 2, 5, 6], modes: ["grade2Symbols"], acceptedInputs: ["|", "out"]),
		makeItem(id: "st", announce: "S T", dots: [3, 4], modes: ["grade2Symbols"], acceptedInputs: ["/", "still"]),
		makeItem(id: "ch", announce: "C H", dots: [1, 6], modes: ["grade2Symbols"], acceptedInputs: ["*", "child"]),
		makeItem(id: "wh", announce: "W H", dots: [1, 5, 6], modes: ["grade2Symbols"], acceptedInputs: [":", "which"]),
		makeItem(id: "ing", announce: "I N G", dots: [3, 4, 6], modes: ["grade2Symbols"], acceptedInputs: ["+"]),
		makeItem(id: "dis", announce: "dis", dots: [2, 5, 6], modes: ["grade2Symbols"], acceptedInputs: ["4", "."]),
		makeItem(id: "con", announce: "con", dots: [2, 5], modes: ["grade2Symbols"], acceptedInputs: ["3", ":"]),
		makeItem(id: "of", announce: "Of", dots: [1, 2, 3, 5, 6], modes: ["grade2Symbols"], acceptedInputs: ["("]),
		makeItem(id: "with", announce: "with", dots: [2, 3, 4, 5, 6], modes: ["grade2Symbols"], acceptedInputs: [")"]),
		makeItem(id: "and", announce: "and", dots: [1, 2, 3, 4, 6], modes: ["grade2Symbols"], acceptedInputs: ["&"]),
		makeItem(id: "for", announce: "for", dots: [1, 2, 3, 4, 5, 6], modes: ["grade2Symbols"], acceptedInputs: ["="]),
		makeItem(id: "the", announce: "The", dots: [2, 3, 4, 6], modes: ["grade2Symbols"], acceptedInputs: ["!"])
	]

	static let grade2Words: [BrailleItem] = [
		makeItem(id: "but", announce: "But", dots: [1, 2], modes: ["grade2Words"], acceptedInputs: ["b"]),
		makeItem(id: "can", announce: "Can", dots: [1, 4], modes: ["grade2Words"], acceptedInputs: ["c"]),
		makeItem(id: "do", announce: "Do", dots: [1, 4, 5], modes: ["grade2Words"], acceptedInputs: ["d"]),
		makeItem(id: "every", announce: "Every", dots: [1, 5], modes: ["grade2Words"], acceptedInputs: ["e"]),
		makeItem(id: "from", announce: "From", dots: [1, 2, 4], modes: ["grade2Words"], acceptedInputs: ["f"]),
		makeItem(id: "go", announce: "Go", dots: [1, 2, 4, 5], modes: ["grade2Words"], acceptedInputs: ["g"]),
		makeItem(id: "have", announce: "Have", dots: [1, 2, 5], modes: ["grade2Words"], acceptedInputs: ["h"]),
		makeItem(id: "just", announce: "Just", dots: [2, 4, 5], modes: ["grade2Words"], acceptedInputs: ["j"]),
		makeItem(id: "knowledge", announce: "Knowledge", dots: [1, 3], modes: ["grade2Words"], acceptedInputs: ["k"]),
		makeItem(id: "like", announce: "Like", dots: [1, 2, 3], modes: ["grade2Words"], acceptedInputs: ["l"]),
		makeItem(id: "more", announce: "More", dots: [1, 3, 4], modes: ["grade2Words"], acceptedInputs: ["m"]),
		makeItem(id: "not", announce: "Not", dots: [1, 3, 4, 5], modes: ["grade2Words"], acceptedInputs: ["n"]),
		makeItem(id: "people", announce: "People", dots: [1, 2, 3, 4], modes: ["grade2Words"], acceptedInputs: ["p"]),
		makeItem(id: "quite", announce: "Quite", dots: [1, 2, 3, 4, 5], modes: ["grade2Words"], acceptedInputs: ["q"]),
		makeItem(id: "rather", announce: "Rather", dots: [1, 2, 3, 5], modes: ["grade2Words"], acceptedInputs: ["r"]),
		makeItem(id: "so", announce: "So", dots: [2, 3, 4], modes: ["grade2Words"], acceptedInputs: ["s"]),
		makeItem(id: "that", announce: "That", dots: [2, 3, 4, 5], modes: ["grade2Words"], acceptedInputs: ["t"]),
		makeItem(id: "us", announce: "Us", dots: [1, 3, 6], modes: ["grade2Words"], acceptedInputs: ["u"]),
		makeItem(id: "very", announce: "Very", dots: [1, 2, 3, 6], modes: ["grade2Words"], acceptedInputs: ["v"]),
		makeItem(id: "will", announce: "Will", dots: [2, 4, 5, 6], modes: ["grade2Words"], acceptedInputs: ["w"]),
		makeItem(id: "it", announce: "It", dots: [1, 3, 4, 6], modes: ["grade2Words"], acceptedInputs: ["x"]),
		makeItem(id: "you", announce: "You", dots: [1, 3, 4, 5, 6], modes: ["grade2Words"], acceptedInputs: ["y"]),
		makeItem(id: "as", announce: "As", dots: [1, 3, 5, 6], modes: ["grade2Words"], acceptedInputs: ["z"]),
		makeItem(id: "this", announce: "This", dots: [1, 4, 5, 6], modes: ["grade2Words"], acceptedInputs: ["?"]),
		makeItem(id: "which", announce: "Which", dots: [1, 5, 6], modes: ["grade2Words"], acceptedInputs: ["w", ":"]),
		makeItem(id: "child", announce: "Child", dots: [1, 6], modes: ["grade2Words"], acceptedInputs: ["c", "*"]),
		makeItem(id: "shall", announce: "Shall", dots: [1, 4, 6], modes: ["grade2Words"], acceptedInputs: ["s", "%"])
	]

	static let grade2ShortformWords: [BrailleItem] = [
		makeItem(id: "be", announce: "Be", dots: [2, 3], modes: ["grade2Shortforms"], acceptedInputs: ["2"], textTokenSequences: [["2"]]),
		makeItem(id: "in", announce: "In", dots: [3, 5], modes: ["grade2Shortforms"], acceptedInputs: ["9"], textTokenSequences: [["9"]]),
		makeItem(id: "enough", announce: "Enough", dots: [2, 6], modes: ["grade2Shortforms"], acceptedInputs: ["5"], textTokenSequences: [["5"]]),
		makeItem(id: "his", announce: "His", dots: [2, 3, 6], modes: ["grade2Shortforms"], acceptedInputs: ["8"], textTokenSequences: [["8"]]),
		makeItem(id: "was", announce: "Was", dots: [3, 5, 6], modes: ["grade2Shortforms"], acceptedInputs: ["7"], textTokenSequences: [["7"]]),
		makeItem(id: "were", announce: "Were", dots: [2, 3, 5, 6], modes: ["grade2Shortforms"], acceptedInputs: ["0"], textTokenSequences: [["0"]]),
		makeSequenceItem(id: "children", announce: "Children", sequenceDots: [[1, 6], [1, 3, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["*", "n"]]),
		makeSequenceItem(id: "could", announce: "Could", sequenceDots: [[1, 4], [1, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["c", "d"]]),
		makeSequenceItem(id: "first", announce: "First", sequenceDots: [[1, 2, 4], [3, 4]], modes: ["grade2Shortforms"], textTokenSequences: [["f", "/"]]),
		makeSequenceItem(id: "good", announce: "Good", sequenceDots: [[1, 2, 4, 5], [1, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["g", "d"]]),
		makeSequenceItem(id: "letter", announce: "Letter", sequenceDots: [[1, 2, 3], [1, 2, 3, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["l", "r"]]),
		makeSequenceItem(id: "must", announce: "Must", sequenceDots: [[1, 3, 4], [3, 4]], modes: ["grade2Shortforms"], textTokenSequences: [["m", "/"]]),
		makeSequenceItem(id: "quick", announce: "Quick", sequenceDots: [[1, 2, 3, 4, 5], [1, 3]], modes: ["grade2Shortforms"], textTokenSequences: [["q", "k"]]),
		makeSequenceItem(id: "paid", announce: "Paid", sequenceDots: [[1, 2, 3, 4], [1, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["p", "d"]]),
		makeSequenceItem(id: "said", announce: "Said", sequenceDots: [[2, 3, 4], [1, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["s", "d"]]),
		makeSequenceItem(id: "would", announce: "Would", sequenceDots: [[2, 4, 5, 6], [1, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["w", "d"]]),
		makeSequenceItem(id: "should", announce: "Should", sequenceDots: [[1, 4, 6], [1, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["%", "d"]]),
		makeSequenceItem(id: "its", announce: "Its", sequenceDots: [[1, 3, 4, 6], [2, 3, 4]], modes: ["grade2Shortforms"], textTokenSequences: [["x", "s"]]),
		makeSequenceItem(id: "your", announce: "Your", sequenceDots: [[1, 3, 4, 5, 6], [1, 2, 3, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["y", "r"]]),
		makeSequenceItem(id: "him", announce: "Him", sequenceDots: [[1, 2, 5], [1, 3, 4]], modes: ["grade2Shortforms"], textTokenSequences: [["h", "m"]]),
		makeSequenceItem(id: "much", announce: "Much", sequenceDots: [[1, 3, 4], [1, 6]], modes: ["grade2Shortforms"], textTokenSequences: [["m", "*"]]),
		makeSequenceItem(id: "such", announce: "Such", sequenceDots: [[2, 3, 4], [1, 6]], modes: ["grade2Shortforms"], textTokenSequences: [["s", "*"]]),
		makeSequenceItem(id: "because", announce: "Because", sequenceDots: [[2, 3], [1, 4]], modes: ["grade2Shortforms"], textTokenSequences: [["2", "c"]]),
		makeSequenceItem(id: "before", announce: "Before", sequenceDots: [[2, 3], [1, 2, 4]], modes: ["grade2Shortforms"], textTokenSequences: [["2", "f"]]),
		makeSequenceItem(id: "behind", announce: "Behind", sequenceDots: [[2, 3], [1, 2, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["2", "h"]]),
		makeSequenceItem(id: "below", announce: "Below", sequenceDots: [[2, 3], [1, 2, 3]], modes: ["grade2Shortforms"], textTokenSequences: [["2", "l"]]),
		makeSequenceItem(id: "beneath", announce: "Beneath", sequenceDots: [[2, 3], [1, 3, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["2", "n"]]),
		makeSequenceItem(id: "beside", announce: "Beside", sequenceDots: [[2, 3], [2, 3, 4]], modes: ["grade2Shortforms"], textTokenSequences: [["2", "s"]]),
		makeSequenceItem(id: "between", announce: "Between", sequenceDots: [[2, 3], [2, 3, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["2", "t"]]),
		makeSequenceItem(id: "beyond", announce: "Beyond", sequenceDots: [[2, 3], [1, 3, 4, 5, 6]], modes: ["grade2Shortforms"], textTokenSequences: [["2", "y"]]),
		makeSequenceItem(id: "today", announce: "Today", sequenceDots: [[2, 3, 4, 5], [1, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["t", "d"]]),
		makeSequenceItem(id: "tomorrow", announce: "Tomorrow", sequenceDots: [[2, 3, 4, 5], [1, 3, 4]], modes: ["grade2Shortforms"], textTokenSequences: [["t", "m"]]),
		makeSequenceItem(id: "tonight", announce: "Tonight", sequenceDots: [[2, 3, 4, 5], [1, 3, 4, 5]], modes: ["grade2Shortforms"], textTokenSequences: [["t", "n"]])
	]

	static let grade2Dot5Initials: [BrailleItem] = [
		makeSequenceItem(id: "day", announce: "Day", sequenceDots: [[5], [1, 4, 5]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "d"]]),
		makeSequenceItem(id: "ever", announce: "Ever", sequenceDots: [[5], [1, 5]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "e"]]),
		makeSequenceItem(id: "father", announce: "Father", sequenceDots: [[5], [1, 2, 4]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "f"]]),
		makeSequenceItem(id: "here", announce: "Here", sequenceDots: [[5], [1, 2, 5]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "h"]]),
		makeSequenceItem(id: "know", announce: "Know", sequenceDots: [[5], [1, 3]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "k"]]),
		makeSequenceItem(id: "lord", announce: "Lord", sequenceDots: [[5], [1, 2, 3]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "l"]]),
		makeSequenceItem(id: "mother", announce: "Mother", sequenceDots: [[5], [1, 3, 4]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "m"]]),
		makeSequenceItem(id: "name", announce: "Name", sequenceDots: [[5], [1, 3, 4, 5]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "n"]]),
		makeSequenceItem(id: "one", announce: "One", sequenceDots: [[5], [1, 3, 5]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "o"]]),
		makeSequenceItem(id: "part", announce: "Part", sequenceDots: [[5], [1, 2, 3, 4]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "p"]]),
		makeSequenceItem(id: "question", announce: "Question", sequenceDots: [[5], [1, 2, 3, 4, 5]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "q"]]),
		makeSequenceItem(id: "right", announce: "Right", sequenceDots: [[5], [1, 2, 3, 5]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "r"]]),
		makeSequenceItem(id: "some", announce: "Some", sequenceDots: [[5], [2, 3, 4]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "s"]]),
		makeSequenceItem(id: "time", announce: "Time", sequenceDots: [[5], [2, 3, 4, 5]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "t"]]),
		makeSequenceItem(id: "there", announce: "T H E R E", sequenceDots: [[5], [2, 3, 4, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "!"]]),
		makeSequenceItem(id: "through", announce: "Through", sequenceDots: [[5], [1, 4, 5, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "?"]]),
		makeSequenceItem(id: "under", announce: "Under", sequenceDots: [[5], [1, 3, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "u"]]),
		makeSequenceItem(id: "where", announce: "Where", sequenceDots: [[5], [1, 5, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", ":"]]),
		makeSequenceItem(id: "work", announce: "Work", sequenceDots: [[5], [2, 4, 5, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "w"]]),
		makeSequenceItem(id: "young", announce: "Young", sequenceDots: [[5], [1, 3, 4, 5, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "y"]]),
		makeSequenceItem(id: "character", announce: "Character", sequenceDots: [[5], [1, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "*"]]),
		makeSequenceItem(id: "ought", announce: "Ought", sequenceDots: [[5], [1, 2, 5, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "|"]])
	]

	static let grade2Dot45Initials: [BrailleItem] = [
		makeSequenceItem(id: "upon", announce: "Upon", sequenceDots: [[4, 5], [1, 3, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "u"]]),
		makeSequenceItem(id: "word", announce: "Word", sequenceDots: [[4, 5], [2, 4, 5, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "w"]]),
		makeSequenceItem(id: "these", announce: "These", sequenceDots: [[4, 5], [2, 3, 4, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "!"]]),
		makeSequenceItem(id: "those", announce: "Those", sequenceDots: [[4, 5], [1, 4, 5, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "?"]]),
		makeSequenceItem(id: "whose", announce: "Whose", sequenceDots: [[4, 5], [1, 5, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", ":"]])
	]

	static let grade2Suffixes: [BrailleItem] = [
		makeSequenceItem(id: "ance", announce: "A N C E", sequenceDots: [[4, 6], [1, 5]], modes: ["grade2Suffixes"], acceptedInputs: ["-ance", "ε", ".e"], textTokenSequences: [[".", "e"]]),
		makeSequenceItem(id: "sion", announce: "S I O N", sequenceDots: [[4, 6], [1, 3, 4, 5]], modes: ["grade2Suffixes"], acceptedInputs: ["-sion", ".n"], textTokenSequences: [[".", "n"]]),
		makeSequenceItem(id: "less", announce: "L E S S", sequenceDots: [[4, 6], [2, 3, 4]], modes: ["grade2Suffixes"], acceptedInputs: ["-less", ".s"], textTokenSequences: [[".", "s"]]),
		makeSequenceItem(id: "ound", announce: "O U N D", sequenceDots: [[4, 6], [1, 4, 5]], modes: ["grade2Suffixes"], acceptedInputs: ["-ound", ".d"], textTokenSequences: [[".", "d"]]),
		makeSequenceItem(id: "ount", announce: "O U N T", sequenceDots: [[4, 6], [2, 3, 4, 5]], modes: ["grade2Suffixes"], acceptedInputs: ["-ount", ".t"], textTokenSequences: [[".", "t"]]),
		makeSequenceItem(id: "ence", announce: "E N C E", sequenceDots: [[5, 6], [1, 5]], modes: ["grade2Suffixes"], acceptedInputs: ["-ence", ";e", "e"], textTokenSequences: [[";", "e"]]),
		makeSequenceItem(id: "ong", announce: "O N G", sequenceDots: [[5, 6], [1, 2, 4, 5]], modes: ["grade2Suffixes"], acceptedInputs: ["-ong", ";g", "g"], textTokenSequences: [[";", "g"]]),
		makeSequenceItem(id: "ful", announce: "F U L", sequenceDots: [[5, 6], [1, 2, 3]], modes: ["grade2Suffixes"], acceptedInputs: ["-ful", ";l", "l"], textTokenSequences: [[";", "l"]]),
		makeSequenceItem(id: "tion", announce: "T I O N", sequenceDots: [[5, 6], [2, 3, 4, 5]], modes: ["grade2Suffixes"], acceptedInputs: ["-tion", ";t", "t"], textTokenSequences: [[";", "t"]]),
		makeSequenceItem(id: "ness", announce: "N E S S", sequenceDots: [[5, 6], [1, 3, 4, 5]], modes: ["grade2Suffixes"], acceptedInputs: ["-ness", ";n", "n"], textTokenSequences: [[";", "n"]]),
		makeSequenceItem(id: "ment", announce: "M E N T", sequenceDots: [[5, 6], [1, 3, 4]], modes: ["grade2Suffixes"], acceptedInputs: ["-ment", ";m", "m"], textTokenSequences: [[";", "m"]]),
		makeSequenceItem(id: "ity", announce: "I T Y", sequenceDots: [[5, 6], [1, 3, 4, 5, 6]], modes: ["grade2Suffixes"], acceptedInputs: ["-ity", ";y", "y"], textTokenSequences: [[";", "y"]])
	]

	static let grade2Dot456Initials: [BrailleItem] = [
		makeSequenceItem(id: "cannot", announce: "Cannot", sequenceDots: [[4, 5, 6], [1, 4]], modes: ["grade2Dot456Initials"], textTokenSequences: [["cannot"]]),
		makeSequenceItem(id: "had", announce: "Had", sequenceDots: [[4, 5, 6], [1, 2, 5]], modes: ["grade2Dot456Initials"], textTokenSequences: [["had"]]),
		makeSequenceItem(id: "many", announce: "Many", sequenceDots: [[4, 5, 6], [1, 3, 4]], modes: ["grade2Dot456Initials"], textTokenSequences: [["many"]]),
		makeSequenceItem(id: "spirit", announce: "Spirit", sequenceDots: [[4, 5, 6], [2, 3, 4]], modes: ["grade2Dot456Initials"], textTokenSequences: [["spirit"]]),
		makeSequenceItem(id: "their", announce: "T H E I R", sequenceDots: [[4, 5, 6], [2, 3, 4, 6]], modes: ["grade2Dot456Initials"], textTokenSequences: [["their"]]),
		makeSequenceItem(id: "world", announce: "World", sequenceDots: [[4, 5, 6], [2, 4, 5, 6]], modes: ["grade2Dot456Initials"], textTokenSequences: [["world"]])
	]

	static let typingSimpleHomeRowItems: [BrailleItem] = [
		makeTypingItem(key: "a", announce: "a", modes: ["typingSimpleHomeRow"]),
		makeTypingItem(key: "s", announce: "s", modes: ["typingSimpleHomeRow"]),
		makeTypingItem(key: "d", announce: "d", modes: ["typingSimpleHomeRow"]),
		makeTypingItem(key: "f", announce: "f", modes: ["typingSimpleHomeRow"]),
		makeTypingItem(key: "j", announce: "j", modes: ["typingSimpleHomeRow"]),
		makeTypingItem(key: "k", announce: "k", modes: ["typingSimpleHomeRow"]),
		makeTypingItem(key: "l", announce: "l", modes: ["typingSimpleHomeRow"]),
		makeTypingItem(key: ";", announce: "semicolon", modes: ["typingSimpleHomeRow"])
	]

	static let typingHomeRowItems: [BrailleItem] = [
		makeTypingItem(key: "a", announce: "a", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: "s", announce: "s", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: "d", announce: "d", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: "f", announce: "f", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: "g", announce: "g", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: "h", announce: "h", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: "j", announce: "j", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: "k", announce: "k", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: "l", announce: "l", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: ";", announce: "semicolon", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"]),
		makeTypingItem(key: "'", announce: "apostrophe", modes: ["typingHomeRow", "typingHomeTopRow", "typingHomeBottomRow"])
	]

	static let typingTopRowItems: [BrailleItem] = [
		makeTypingItem(key: "q", announce: "q", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "w", announce: "w", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "e", announce: "e", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "r", announce: "r", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "t", announce: "t", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "y", announce: "y", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "u", announce: "u", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "i", announce: "i", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "o", announce: "o", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "p", announce: "p", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "[", announce: "left bracket", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "]", announce: "right bracket", modes: ["typingHomeTopRow"]),
		makeTypingItem(key: "\\", announce: "backslash", modes: ["typingHomeTopRow"])
	]

	static let typingBottomRowItems: [BrailleItem] = [
		makeTypingItem(key: "z", announce: "z", modes: ["typingHomeBottomRow"]),
		makeTypingItem(key: "x", announce: "x", modes: ["typingHomeBottomRow"]),
		makeTypingItem(key: "c", announce: "c", modes: ["typingHomeBottomRow"]),
		makeTypingItem(key: "v", announce: "v", modes: ["typingHomeBottomRow"]),
		makeTypingItem(key: "b", announce: "b", modes: ["typingHomeBottomRow"]),
		makeTypingItem(key: "n", announce: "n", modes: ["typingHomeBottomRow"]),
		makeTypingItem(key: "m", announce: "m", modes: ["typingHomeBottomRow"]),
		makeTypingItem(key: ",", announce: "comma", modes: ["typingHomeBottomRow"]),
		makeTypingItem(key: ".", announce: "period", modes: ["typingHomeBottomRow"]),
		makeTypingItem(key: "/", announce: "slash", modes: ["typingHomeBottomRow"])
	]

	static let brailleOnlyRegistry: [BrailleItem] =
		grade1Letters +
		grade1Numbers +
		grade2Symbols +
		grade2Words +
		grade2ShortformWords +
		grade2Dot5Initials +
		grade2Dot45Initials +
		grade2Suffixes +
		grade2Dot456Initials

	static let grade1MoleInvasionItems: [BrailleItem] = grade1Letters + grade1Numbers
	static let grade2MoleInvasionItems: [BrailleItem] =
		grade2Symbols +
		grade2Words +
		grade2ShortformWords +
		grade2Dot5Initials +
		grade2Dot45Initials +
		grade2Suffixes +
		grade2Dot456Initials

	static let allItems: [BrailleItem] =
		brailleOnlyRegistry +
		typingSimpleHomeRowItems +
		typingHomeRowItems +
		typingTopRowItems +
		typingBottomRowItems

	static let modeSections: [ModeSection] = [
		ModeSection(
			id: "grade1",
			title: "Grade 1",
			options: [
				("letters-aj", "Letters A-J"),
				("letters-at", "Letters A-T"),
				("grade1Letters", "Letters Only"),
				("grade1Numbers", "Numbers Only"),
				("grade1LettersNumbers", "Letters and Numbers"),
				("grade1MoleInvasion", "Grade 1 Mole Invasion")
			]
		),
		ModeSection(
			id: "grade2",
			title: "Grade 2",
			options: [
				("grade2Symbols", "Symbol Contractions"),
				("grade2Words", "Whole Word Contractions"),
				("grade2Shortforms", "Short-form Words"),
				("grade2Suffixes", "Suffixes"),
				("grade2Dot5Initials", "Dot 5 Initials"),
				("grade2Dot45Initials", "Dots 4 5 Initials"),
				("grade2Dot456Initials", "Dots 4 5 6 Initials"),
				("grade2MoleInvasion", "Grade 2 Mole Invasion")
			]
		),
		ModeSection(
			id: "moleBattles",
			title: "Mole Battles",
			options: [
				("grade1ThreeLetterBlitz", "3-Letter Words"),
				("grade1FourLetterBlitz", "4-Letter Words"),
				("grade1MoleBlitz", "Grade 1 Mole Battle"),
				(WordWarCatalog.modeId, "Holy Moley Word War")
			]
		),
		ModeSection(
			id: "typing",
			title: "Typing",
			options: [
				("typingSimpleHomeRow", "Simple Home Row"),
				("typingHomeRow", "QWERTY Home Row"),
				("typingHomeTopRow", "QWERTY Home Row + Top Row"),
				("typingHomeBottomRow", "QWERTY Home Row + Bottom Row")
			]
		),
		ModeSection(
			id: "custom",
			title: "Custom",
			options: [
				("customMoles", "Custom Moles")
			]
		)
	]

	static let modeOptions: [ModeOption] = modeSections.flatMap(\.options)

	private static let qwertyModeIDs: Set<String> = [
		"typingSimpleHomeRow",
		"typingHomeRow",
		"typingHomeTopRow",
		"typingHomeBottomRow"
	]

	private static let qwertyUnsupportedBrailleModeIDs: Set<String> = [
		"grade2Dot456Initials"
	]

	private static let bsiExcludedModeIDs: Set<String> = qwertyModeIDs
	private static let bufferedTextUnsupportedModeIDs: Set<String> = [
		"grade2Suffixes"
	]

	private static func letterInRange(_ item: BrailleItem, end: Character) -> Bool {
		guard let first = item.id.uppercased().first else { return false }
		guard let scalar = first.unicodeScalars.first?.value else { return false }
		guard let endScalar = String(end).unicodeScalars.first?.value else { return false }
		return scalar >= 65 && scalar <= endScalar
	}

	static func filteredModeOptions(for inputMode: InputMode) -> [ModeOption] {
		modeOptions.filter { option in
			switch inputMode {
			case .qwerty:
				return !qwertyUnsupportedBrailleModeIDs.contains(option.id)
			case .perkins:
				return !qwertyModeIDs.contains(option.id)
			case .brailleDisplayInput, .brailleText, .oneHandedBrailleInput:
				return !bsiExcludedModeIDs.contains(option.id) && !bufferedTextUnsupportedModeIDs.contains(option.id)
			}
		}
	}

	static func filteredModeSections(for inputMode: InputMode) -> [ModeSection] {
		let allowedIDs = Set(filteredModeOptions(for: inputMode).map(\.id))
		return modeSections.compactMap { section in
			let options = section.options.filter { allowedIDs.contains($0.id) }
			guard !options.isEmpty else { return nil }
			return ModeSection(id: section.id, title: section.title, options: options)
		}
	}

	static func customMoleSections(for inputMode: InputMode) -> [CustomMoleSection] {
		[
			CustomMoleSection(id: "grade1Letters", title: "Grade 1 Letters", items: grade1Letters),
			CustomMoleSection(id: "grade1Numbers", title: "Grade 1 Numbers", items: grade1Numbers),
			CustomMoleSection(id: "grade2Symbols", title: "Grade 2 Contractions", items: grade2Symbols),
			CustomMoleSection(id: "grade2Words", title: "Grade 2 Whole-Word Contractions", items: grade2Words),
			CustomMoleSection(id: "grade2Shortforms", title: "Grade 2 Shortform Words", items: grade2ShortformWords),
			CustomMoleSection(id: "grade2Dot5Initials", title: "Grade 2 Dot 5 Initials", items: grade2Dot5Initials),
			CustomMoleSection(id: "grade2Dot45Initials", title: "Grade 2 Dot 45 Initials", items: grade2Dot45Initials),
			CustomMoleSection(id: "grade2Suffixes", title: "Grade 2 Suffixes", items: grade2Suffixes),
			CustomMoleSection(id: "grade2Dot456Initials", title: "Grade 2 Dot 456 Initials", items: grade2Dot456Initials)
		]
		.map { section in
			CustomMoleSection(
				id: section.id,
				title: section.title,
				items: section.items.filter { isCustomMoleItemAllowed($0, inputMode: inputMode) }
			)
		}
		.filter { !$0.items.isEmpty }
	}

	static func customMoleItems(for inputMode: InputMode) -> [BrailleItem] {
		customMoleSections(for: inputMode).flatMap(\.items)
	}

	static func customMoleItems(for ids: [String], inputMode: InputMode) -> [BrailleItem] {
		let items = customMoleItems(for: inputMode)
		let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
		return ids.compactMap { itemByID[$0] }
	}

	static func sanitizedModeId(_ modeId: String, for inputMode: InputMode) -> String {
		let allowed = filteredModeOptions(for: inputMode)
		if allowed.contains(where: { $0.id == modeId }) {
			return modeId
		}

		switch inputMode {
		case .qwerty:
			return qwertyUnsupportedBrailleModeIDs.contains(modeId) ? "grade2Symbols" : modeId
		case .perkins, .brailleText, .brailleDisplayInput, .oneHandedBrailleInput:
			return "grade1Letters"
		}
	}

	static func getItems(for modeId: String, inputMode: InputMode = .qwerty) -> [BrailleItem] {
		switch modeId {
		case "letters-aj":
			return grade1Letters.filter { letterInRange($0, end: "J") }
		case "letters-at":
			return grade1Letters.filter { letterInRange($0, end: "T") }
		case "grade1MoleInvasion":
			return grade1MoleInvasionItems
		case "grade2MoleInvasion":
			return filteredGrade2InvasionItems(for: inputMode)
		default:
			return allItems.filter { $0.modeTags.contains(modeId) }
		}
	}

	private static func isCustomMoleItemAllowed(_ item: BrailleItem, inputMode: InputMode) -> Bool {
		switch inputMode {
		case .qwerty:
			return !item.modeTags.contains("grade2Dot456Initials")
		case .brailleText, .brailleDisplayInput, .oneHandedBrailleInput:
			return !item.modeTags.contains("grade2Suffixes")
		case .perkins:
			return true
		}
	}

	private static func filteredGrade2InvasionItems(for inputMode: InputMode) -> [BrailleItem] {
		switch inputMode {
		case .qwerty:
			return grade2MoleInvasionItems.filter { !$0.modeTags.contains("grade2Dot456Initials") }
		case .brailleText, .brailleDisplayInput, .oneHandedBrailleInput:
			return grade2MoleInvasionItems.filter { !$0.modeTags.contains("grade2Suffixes") }
		case .perkins:
			return grade2MoleInvasionItems
		}
	}

	static func label(for modeId: String) -> String {
		modeOptions.first(where: { $0.id == modeId })?.label ?? "Letters and numbers (Grade 1)"
	}

	static let grade1ReferenceSections: [ReferenceSection] = [
		ReferenceSection(
			id: "grade1Letters",
			title: "Grade 1 Letters",
			rows: referenceRows(for: grade1Letters)
		),
		ReferenceSection(
			id: "grade1Numbers",
			title: "Grade 1 Numbers",
			rows: referenceRows(for: grade1Numbers)
		)
	]

	static let grade2ReferenceSections: [ReferenceSection] = [
		ReferenceSection(id: "grade2Symbols", title: "Grade 2 Symbols", rows: referenceRows(for: grade2Symbols)),
		ReferenceSection(id: "grade2Words", title: "Grade 2 Whole-Word Contractions", rows: referenceRows(for: grade2Words)),
		ReferenceSection(id: "grade2Shortforms", title: "Grade 2 Shortform Words", rows: referenceRows(for: grade2ShortformWords)),
		ReferenceSection(id: "grade2Dot5Initials", title: "Grade 2 Dot 5 Initials", rows: referenceRows(for: grade2Dot5Initials)),
		ReferenceSection(id: "grade2Dot45Initials", title: "Grade 2 Dot 45 Initials", rows: referenceRows(for: grade2Dot45Initials)),
		ReferenceSection(id: "grade2Suffixes", title: "Grade 2 Suffixes", rows: referenceRows(for: grade2Suffixes)),
		ReferenceSection(id: "grade2Dot456Initials", title: "Grade 2 Dot 456 Initials", rows: referenceRows(for: grade2Dot456Initials))
	]
}

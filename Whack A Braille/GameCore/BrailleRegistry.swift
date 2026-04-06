import Foundation

enum BrailleRegistry {

	typealias ModeOption = (id: String, label: String)

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

	private static let braillePatternBase = 0x2800

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

	private static func brailleUnicode(for dots: [Int]) -> String {
		let mask = dotsToMask(dots)
		guard let scalar = UnicodeScalar(braillePatternBase + mask) else { return "" }
		return String(Character(scalar))
	}

	private static func dotsText(for sequence: [[Int]]) -> String {
		sequence
			.map { step in step.map(String.init).joined() }
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
		makeItem(id: "wh", announce: "W H", dots: [1, 5, 6], modes: ["grade2Symbols"], acceptedInputs: [":"]),
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
		makeSequenceItem(id: "there", announce: "There", sequenceDots: [[5], [2, 3, 4, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "!"]]),
		makeSequenceItem(id: "under", announce: "Under", sequenceDots: [[5], [1, 3, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "u"]]),
		makeSequenceItem(id: "work", announce: "Work", sequenceDots: [[5], [2, 4, 5, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "w"]]),
		makeSequenceItem(id: "young", announce: "Young", sequenceDots: [[5], [1, 3, 4, 5, 6]], modes: ["grade2Dot5Initials"], textTokenSequences: [["'", "y"]])
	]

	static let grade2Dot45Initials: [BrailleItem] = [
		makeSequenceItem(id: "upon", announce: "Upon", sequenceDots: [[4, 5], [1, 3, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "u"]]),
		makeSequenceItem(id: "word", announce: "Word", sequenceDots: [[4, 5], [2, 4, 5, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "w"]]),
		makeSequenceItem(id: "these", announce: "These", sequenceDots: [[4, 5], [2, 3, 4, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "!"]]),
		makeSequenceItem(id: "through", announce: "Through", sequenceDots: [[4, 5], [1, 4, 5, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "?"]]),
		makeSequenceItem(id: "character", announce: "Character", sequenceDots: [[4, 5], [1, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "*"]]),
		makeSequenceItem(id: "where", announce: "Where", sequenceDots: [[4, 5], [1, 5, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", ":"]]),
		makeSequenceItem(id: "ought", announce: "Ought", sequenceDots: [[4, 5], [1, 2, 5, 6]], modes: ["grade2Dot45Initials"], textTokenSequences: [["~", "|"]])
	]

	static let grade2Dot46Finals: [BrailleItem] = [
		makeSequenceItem(id: "ance", announce: "A N C E", sequenceDots: [[4, 6], [1, 5]], modes: ["grade2Dot46Finals"], acceptedInputs: ["-ance", "ε"], textTokenSequences: [[".", "e"]]),
		makeSequenceItem(id: "sion", announce: "S I O N", sequenceDots: [[4, 6], [1, 3, 4, 5]], modes: ["grade2Dot46Finals"], acceptedInputs: ["-sion"], textTokenSequences: [[".", "n"]]),
		makeSequenceItem(id: "less", announce: "L E S S", sequenceDots: [[4, 6], [2, 3, 4]], modes: ["grade2Dot46Finals"], acceptedInputs: ["-less"], textTokenSequences: [[".", "s"]]),
		makeSequenceItem(id: "ound", announce: "O U N D", sequenceDots: [[4, 6], [1, 4, 5]], modes: ["grade2Dot46Finals"], acceptedInputs: ["-ound"], textTokenSequences: [[".", "d"]]),
		makeSequenceItem(id: "ount", announce: "O U N T", sequenceDots: [[4, 6], [2, 3, 4, 5]], modes: ["grade2Dot46Finals"], acceptedInputs: ["-ount"], textTokenSequences: [[".", "t"]])
	]

	static let grade2Dot456Initials: [BrailleItem] = [
		makeSequenceItem(id: "those", announce: "Those", sequenceDots: [[4, 5, 6], [1, 4, 5, 6]], modes: ["grade2Dot456Initials"], textTokenSequences: [["?"]]),
		makeSequenceItem(id: "whose", announce: "Whose", sequenceDots: [[4, 5, 6], [1, 5, 6]], modes: ["grade2Dot456Initials"], textTokenSequences: [[":"]]),
		makeSequenceItem(id: "cannot", announce: "Cannot", sequenceDots: [[4, 5, 6], [1, 4]], modes: ["grade2Dot456Initials"], textTokenSequences: [["c"]]),
		makeSequenceItem(id: "had", announce: "Had", sequenceDots: [[4, 5, 6], [1, 2, 5]], modes: ["grade2Dot456Initials"], textTokenSequences: [["h"]]),
		makeSequenceItem(id: "many", announce: "Many", sequenceDots: [[4, 5, 6], [1, 3, 4]], modes: ["grade2Dot456Initials"], textTokenSequences: [["m"]]),
		makeSequenceItem(id: "spirit", announce: "Spirit", sequenceDots: [[4, 5, 6], [2, 3, 4]], modes: ["grade2Dot456Initials"], textTokenSequences: [["s"]]),
		makeSequenceItem(id: "their", announce: "Their", sequenceDots: [[4, 5, 6], [2, 3, 4, 6]], modes: ["grade2Dot456Initials"], textTokenSequences: [["!"]]),
		makeSequenceItem(id: "world", announce: "World", sequenceDots: [[4, 5, 6], [2, 4, 5, 6]], modes: ["grade2Dot456Initials"], textTokenSequences: [["w"]])
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
		grade2Dot5Initials +
		grade2Dot45Initials +
		grade2Dot46Finals +
		grade2Dot456Initials

	static let grade1MoleInvasionItems: [BrailleItem] = grade1Letters + grade1Numbers
	static let grade2MoleInvasionItems: [BrailleItem] =
		grade2Symbols +
		grade2Words +
		grade2Dot5Initials +
		grade2Dot45Initials +
		grade2Dot46Finals +
		grade2Dot456Initials

	static let allItems: [BrailleItem] =
		brailleOnlyRegistry +
		typingSimpleHomeRowItems +
		typingHomeRowItems +
		typingTopRowItems +
		typingBottomRowItems

	static let modeOptions: [ModeOption] = [
		("typingSimpleHomeRow", "Simple Home Row"),
		("typingHomeRow", "QWERTY Home Row"),
		("typingHomeTopRow", "QWERTY Home Row + Top Row"),
		("typingHomeBottomRow", "QWERTY Home Row + Bottom Row"),
		("letters-aj", "Grade 1 Letters A-J"),
		("letters-at", "Grade 1 Letters A-T"),
		("grade1Letters", "Letters only (Grade 1)"),
		("grade1Numbers", "Numbers only (Grade 1)"),
		("grade1LettersNumbers", "Letters and numbers (Grade 1)"),
		("grade1MoleInvasion", "Grade 1 Mole Invasion!"),
		("grade2Symbols", "Grade 2 contractions (symbols)"),
		("grade2Words", "Grade 2 whole-word contractions"),
		("grade2Dot5Initials", "Grade 2 dot 5 initials"),
		("grade2Dot45Initials", "Grade 2 dot 45 initials"),
		("grade2Dot46Finals", "Grade 2 dot 46 finals"),
		("grade2Dot456Initials", "Grade 2 dot 456 initials"),
		("grade2MoleInvasion", "Grade 2 Mole Invasion!")
	]

	private static let qwertyModeIDs: Set<String> = [
		"typingSimpleHomeRow",
		"typingHomeRow",
		"typingHomeTopRow",
		"typingHomeBottomRow"
	]

	private static let bsiExcludedModeIDs: Set<String> = qwertyModeIDs

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
				return true
			case .perkins:
				return !qwertyModeIDs.contains(option.id)
			case .brailleText:
				return !bsiExcludedModeIDs.contains(option.id)
			}
		}
	}

	static func sanitizedModeId(_ modeId: String, for inputMode: InputMode) -> String {
		let allowed = filteredModeOptions(for: inputMode)
		if allowed.contains(where: { $0.id == modeId }) {
			return modeId
		}

		switch inputMode {
		case .qwerty:
			return modeId
		case .perkins, .brailleText:
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
			return grade2MoleInvasionItems
		default:
			return allItems.filter { $0.modeTags.contains(modeId) }
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
		ReferenceSection(id: "grade2Dot5Initials", title: "Grade 2 Dot 5 Initials", rows: referenceRows(for: grade2Dot5Initials)),
		ReferenceSection(id: "grade2Dot45Initials", title: "Grade 2 Dot 45 Initials", rows: referenceRows(for: grade2Dot45Initials)),
		ReferenceSection(id: "grade2Dot46Finals", title: "Grade 2 Dot 46 Finals", rows: referenceRows(for: grade2Dot46Finals)),
		ReferenceSection(id: "grade2Dot456Initials", title: "Grade 2 Dot 456 Initials", rows: referenceRows(for: grade2Dot456Initials))
	]
}

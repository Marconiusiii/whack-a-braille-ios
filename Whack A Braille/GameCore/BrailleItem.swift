import Foundation

struct BrailleItem {
	let id: String
	let displayLabel: String
	let announceText: String
	let dots: [Int]
	let dotMask: Int
	let perkinsKeys: [String]
	let perkinsSequenceDots: [[Int]]
	let perkinsSequenceMasks: [Int]
	let acceptedPerkinsSequences: [[Int]]
	let expectedPerkinsCellCount: Int
	let standardKey: String?
	let acceptedTextInputs: [String]
	let textInputTokenSequences: [[String]]
	let modeTags: Set<String>
	let nato: String?

	var dotPatternText: String {
		let sequence = perkinsSequenceDots.isEmpty ? [dots] : perkinsSequenceDots
		if modeTags.contains(where: BlitzWord.isWordMode) {
			return Self.compactDotPatternText(for: sequence)
		}
		return Self.expandedDotPatternText(for: sequence)
	}

	nonisolated static func compactDotPatternText(for sequence: [[Int]]) -> String {
		let cells = sequence
			.filter { !$0.isEmpty }
			.map { $0.map(String.init).joined(separator: " ") }

		guard !cells.isEmpty else { return "" }
		return "Dots \(cells.joined(separator: ", "))"
	}

	nonisolated private static func expandedDotPatternText(for sequence: [[Int]]) -> String {
		sequence
			.filter { !$0.isEmpty }
			.map { dots in
				let label = dots.count == 1 ? "Dot" : "Dots"
				return "\(label) \(dots.map(String.init).joined(separator: " "))"
			}
			.joined(separator: ", then ")
	}
}

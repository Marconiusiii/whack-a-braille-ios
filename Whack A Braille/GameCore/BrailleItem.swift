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
}

import Foundation

struct BrailleItem {
	let id: String
	let displayLabel: String
	let announceText: String
	let dots: [Int]
	let dotMask: Int
	let perkinsKeys: [String]
	let standardKey: String?
	let acceptedTextInputs: [String]
	let modeTags: Set<String>
	let nato: String?
}

import Foundation

struct BrailleItem {
	let id: String
	let announceText: String

	// Perkins/dot support
	let dots: [Int]
	let dotMask: Int
	let perkinsKeys: [String]

	// Optional QWERTY support
	let standardKey: String?

	// Mode tags for filtering
	let modeTags: Set<String>
}


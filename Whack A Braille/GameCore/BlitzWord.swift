import Foundation

struct BlitzWord: Identifiable, Hashable {
	let text: String

	var id: String { text }
	var letters: [Character] { Array(text) }
	var length: Int { text.count }

	func asBrailleItem(modeId: String) -> BrailleItem? {
		let letterByID = Dictionary(uniqueKeysWithValues: BrailleRegistry.grade1Letters.map { ($0.id, $0) })
		let items = letters.compactMap { letterByID[String($0)] }
		guard items.count == letters.count, let finalItem = items.last else { return nil }

		return BrailleItem(
			id: text,
			displayLabel: text,
			announceText: text,
			dots: finalItem.dots,
			dotMask: finalItem.dotMask,
			perkinsKeys: finalItem.perkinsKeys,
			perkinsSequenceDots: items.map(\.dots),
			perkinsSequenceMasks: items.map(\.dotMask),
			acceptedPerkinsSequences: [items.map(\.dotMask)],
			expectedPerkinsCellCount: items.count,
			standardKey: nil,
			acceptedTextInputs: [text],
			textInputTokenSequences: [letters.map(String.init)],
			modeTags: [modeId],
			nato: nil
		)
	}

	nonisolated static func isGrade1BattleMode(_ modeId: String) -> Bool {
		switch modeId {
		case "grade1ThreeLetterBlitz", "grade1FourLetterBlitz", "grade1MoleBlitz":
			return true
		default:
			return false
		}
	}

	nonisolated static func isWordyMoleMayhemMode(_ modeId: String) -> Bool {
		modeId == WordyMoleMayhemCatalog.modeId
	}

	nonisolated static func isWordMode(_ modeId: String) -> Bool {
		isGrade1BattleMode(modeId) || isWordyMoleMayhemMode(modeId)
	}

	nonisolated static func isBlitzMode(_ modeId: String) -> Bool {
		isWordMode(modeId)
	}

	nonisolated static func allowedLengths(for modeId: String) -> Set<Int> {
		switch modeId {
		case "grade1ThreeLetterBlitz":
			return [3]
		case "grade1FourLetterBlitz":
			return [4]
		case "grade1MoleBlitz":
			return [3, 4, 5]
		default:
			return []
		}
	}

	nonisolated static func pan(forLetterAt index: Int, wordLength: Int) -> Float {
		let maps: [Int: [Float]] = [
			3: [-0.5, 0, 0.5],
			4: [-0.75, -0.25, 0.25, 0.75],
			5: [-1, -0.5, 0, 0.5, 1]
		]
		guard let positions = maps[wordLength], positions.indices.contains(index) else { return 0 }
		return positions[index]
	}
}

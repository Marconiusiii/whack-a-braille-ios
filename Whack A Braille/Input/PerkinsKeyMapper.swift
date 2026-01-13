import Foundation

enum PerkinsKeyMapper {

	// f=1, d=2, s=3, j=4, k=5, l=6 (matches your registry mapping) :contentReference[oaicite:2]{index=2}
	static func dot(forKey key: String) -> Int? {
		switch key.lowercased() {
		case "f": return 1
		case "d": return 2
		case "s": return 3
		case "j": return 4
		case "k": return 5
		case "l": return 6
		default: return nil
		}
	}

	static func mask(forDots dots: Set<Int>) -> Int {
		var mask = 0
		for dot in dots {
			mask |= 1 << (dot - 1)
		}
		return mask
	}
}

import Foundation

enum KeyboardMode: String, CaseIterable, Identifiable {
	case standard
	case perkins

	var id: String { rawValue }

	var label: String {
		switch self {
		case .standard: return "Keyboard: Standard"
		case .perkins: return "Keyboard: Perkins Home Row"
		}
	}
}

enum TouchPadMode: String, CaseIterable, Identifiable {
	case off
	case tabletop
	case screenAway

	var id: String { rawValue }

	var label: String {
		switch self {
		case .off: return "Touch Pad: Off"
		case .tabletop: return "Touch Pad: Tabletop"
		case .screenAway: return "Touch Pad: Screen Away"
		}
	}
}

struct GameSettings {
	var modeId: String = "grade1LettersNumbers"
	var keyboardMode: KeyboardMode = .standard
	var touchPadMode: TouchPadMode = .off

	// If true, braille display users can use enter/space as “whack/submit.”
	// BSI uncontracted can still feel immediate, but contracted/display often need submit.
	var brailleSubmitMode: Bool = false

	var isPerkinsLockedByMode: Bool {
		modeId == "grade2Symbols" || modeId == "grade2Words" || modeId == "everything"
	}

	var effectiveKeyboardMode: KeyboardMode {
		isPerkinsLockedByMode ? .perkins : keyboardMode
	}
}

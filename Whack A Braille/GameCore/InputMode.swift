enum InputMode: String, CaseIterable, Identifiable {
	case qwerty
	case perkins
	case brailleText
	case brailleDisplayInput

	var id: String { rawValue }

	var label: String {
		switch self {
		case .qwerty:
			return "Standard Keyboard or 8-Dot Braille"
		case .perkins:
			return "Perkins Home Row"
		case .brailleText:
			return "Braille Screen Input"
		case .brailleDisplayInput:
			return "Braille Display Input"
		}
	}

	var usesBufferedTextEntry: Bool {
		switch self {
		case .brailleText, .brailleDisplayInput:
			return true
		case .qwerty, .perkins:
			return false
		}
	}
}

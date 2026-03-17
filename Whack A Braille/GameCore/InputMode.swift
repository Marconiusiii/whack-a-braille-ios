enum InputMode: String, CaseIterable, Identifiable {
	case qwerty
	case perkins
	case brailleText

	var id: String { rawValue }
}

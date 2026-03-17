enum Difficulty: String, CaseIterable, Identifiable {
	case training
	case beginner
	case normal
	case supreme

	var id: String { rawValue }

	var label: String {
		switch self {
		case .training:
			return "Training"
		case .beginner:
			return "Beginner"
		case .normal:
			return "Normal"
		case .supreme:
			return "Supreme Mole Whacker"
		}
	}

	var isTimed: Bool {
		self != .training
	}
}

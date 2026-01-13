import UIKit

final class PerkinsKeyboardSink: UIView {

	var isEnabled: Bool = true
	var onChord: ((Int) -> Void)?

	private var activeDots: Set<Int> = []
	private var activeKeys: Set<String> = []

	override var canBecomeFirstResponder: Bool {
		true
	}

	override func didMoveToWindow() {
		super.didMoveToWindow()
		becomeFirstResponder()
	}

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		guard isEnabled else {
			super.pressesBegan(presses, with: event)
			return
		}

		for press in presses {
			guard let key = press.key else { continue }
			let lower = key.charactersIgnoringModifiers.lowercased()

			if let dot = PerkinsKeyMapper.dot(forKey: lower) {
				activeKeys.insert(lower)
				activeDots.insert(dot)
			}
		}

		super.pressesBegan(presses, with: event)
	}

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		guard isEnabled else {
			super.pressesEnded(presses, with: event)
			return
		}

		for press in presses {
			guard let key = press.key else { continue }
			let lower = key.charactersIgnoringModifiers.lowercased()

			if let dot = PerkinsKeyMapper.dot(forKey: lower) {
				activeKeys.remove(lower)
				activeDots.remove(dot)
			}
		}

		// Emit chord when all Perkins keys are released
		if activeKeys.isEmpty {
			let mask = PerkinsKeyMapper.mask(forDots: activeDots)
			activeDots.removeAll()
			if mask != 0 {
				onChord?(mask)
			}
		}

		super.pressesEnded(presses, with: event)
	}

	override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		activeDots.removeAll()
		activeKeys.removeAll()
		super.pressesCancelled(presses, with: event)
	}
}

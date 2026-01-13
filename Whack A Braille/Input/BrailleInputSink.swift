import UIKit

final class BrailleInputSink: UIView, UIKeyInput {

	var onText: ((String) -> Void)?
	var onDelete: (() -> Void)?
	var onKeyCommand: ((UIKeyCommand) -> Void)?

	override var canBecomeFirstResponder: Bool {
		true
	}

	override func didMoveToWindow() {
		super.didMoveToWindow()
		becomeFirstResponder()
	}

	// MARK: - UIKeyInput

	var hasText: Bool {
		false
	}

	func insertText(_ text: String) {
		onText?(text)
	}

	func deleteBackward() {
		onDelete?()
	}

	// MARK: - Hardware keyboard commands

	override var keyCommands: [UIKeyCommand]? {
		[
			UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleKeyCommand(_:))),
			UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleKeyCommand(_:)))
		]
	}

	@objc private func handleKeyCommand(_ command: UIKeyCommand) {
		onKeyCommand?(command)
	}
}

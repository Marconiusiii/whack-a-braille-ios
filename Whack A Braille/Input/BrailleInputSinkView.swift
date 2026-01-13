import SwiftUI
import UIKit

struct BrailleInputSinkView: UIViewRepresentable {

	let gameLoop: GameLoop

	func makeUIView(context: Context) -> BrailleInputSink {
		let view = BrailleInputSink()

		view.onText = { text in
			handleTextInput(text)
		}

		view.onDelete = {
			// optional: handle delete if you want
		}

		view.onKeyCommand = { command in
			handleKeyCommand(command)
		}

		return view
	}

	func updateUIView(_ uiView: BrailleInputSink, context: Context) {
		// nothing to update
	}

	// MARK: - Input routing

	private func handleTextInput(_ text: String) {
		// Multiple characters can arrive at once
		for scalar in text {
			let attempt = Attempt(
				moleId: gameLoop.currentMoleId,
				type: .brailleText,
				dotMask: nil,
				key: nil,
				char: String(scalar)
			)

			gameLoop.handleAttempt(attempt)
		}
	}

	private func handleKeyCommand(_ command: UIKeyCommand) {
		if let input = command.input {
			let attempt = Attempt(
				moleId: gameLoop.currentMoleId,
				type: .qwerty,
				dotMask: nil,
				key: input,
				char: nil
			)

			gameLoop.handleAttempt(attempt)
		}
	}
}

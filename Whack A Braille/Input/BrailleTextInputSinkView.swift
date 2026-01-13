import SwiftUI
import UIKit

struct BrailleTextInputSinkView: UIViewRepresentable {

	let gameLoop: GameLoop

	func makeUIView(context: Context) -> BrailleTextInputSink {
		let view = BrailleTextInputSink()
		view.submissionMode = .submitKey

		view.onTextToken = { token in
			let attempt = Attempt(
				moleId: gameLoop.currentMoleId,
				type: .brailleText,
				dotMask: nil,
				key: nil,
				char: token
			)

			gameLoop.handleAttempt(attempt)
		}

		return view
	}

	func updateUIView(_ uiView: BrailleTextInputSink, context: Context) {
		// nothing
	}
}

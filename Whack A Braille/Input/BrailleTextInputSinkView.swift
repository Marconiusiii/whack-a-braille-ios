import SwiftUI
import UIKit

struct BrailleTextInputSinkView: UIViewRepresentable {

	let gameLoop: GameLoop
	let isEnabled: Bool
	let submissionMode: InputSubmissionMode

	func makeUIView(context: Context) -> BrailleTextInputSink {
		let view = BrailleTextInputSink()
		view.submissionMode = submissionMode

		view.onTextToken = { token in
			if !isEnabled {
				return
			}

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
		uiView.submissionMode = submissionMode
	}
}

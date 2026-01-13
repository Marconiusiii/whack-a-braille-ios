import SwiftUI
import UIKit

struct PerkinsKeyboardSinkView: UIViewRepresentable {

	let gameLoop: GameLoop
	let isEnabled: Bool

	func makeUIView(context: Context) -> PerkinsKeyboardSink {
		let view = PerkinsKeyboardSink()
		view.isEnabled = isEnabled

		view.onChord = { mask in
			let attempt = Attempt(
				moleId: gameLoop.currentMoleId,
				type: .perkins,
				dotMask: mask,
				key: nil,
				char: nil
			)
			gameLoop.handleAttempt(attempt)
		}

		return view
	}

	func updateUIView(_ uiView: PerkinsKeyboardSink, context: Context) {
		uiView.isEnabled = isEnabled
	}
}

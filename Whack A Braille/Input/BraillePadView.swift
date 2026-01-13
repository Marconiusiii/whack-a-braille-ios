import SwiftUI
import UIKit

struct BraillePadView: UIViewRepresentable {

	typealias UIViewType = BraillePadTouchView

	let gameLoop: GameLoop
	let isEnabled: Bool
	let orientation: BraillePadOrientation

	func makeUIView(context: Context) -> BraillePadTouchView {
		let view = BraillePadTouchView()
		view.orientation = orientation

		view.onChord = { (mask: Int) in
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

	func updateUIView(_ uiView: BraillePadTouchView, context: Context) {
		uiView.isHidden = !isEnabled
		uiView.isUserInteractionEnabled = isEnabled
		uiView.orientation = orientation
	}
}


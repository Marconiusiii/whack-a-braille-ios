import SwiftUI
import UIKit

struct BrailleTextInputSinkView: UIViewRepresentable {

	enum SubmissionMode {
		case immediate
		case submitKey
	}

	let gameLoop: GameLoop
	let isEnabled: Bool
	let submissionMode: SubmissionMode

	func makeUIView(context: Context) -> NoKeyboardTextField {
		let tf = NoKeyboardTextField()
		tf.delegate = context.coordinator

		tf.autocorrectionType = .no
		tf.spellCheckingType = .no
		tf.smartDashesType = .no
		tf.smartQuotesType = .no
		tf.smartInsertDeleteType = .no
		tf.keyboardType = .default
		tf.returnKeyType = .done
		tf.enablesReturnKeyAutomatically = false
		tf.clearButtonMode = .never
		tf.textContentType = nil

		tf.isAccessibilityElement = false
		tf.accessibilityElementsHidden = true

		return tf
	}

	func updateUIView(_ uiView: NoKeyboardTextField, context: Context) {
		context.coordinator.gameLoop = gameLoop
		context.coordinator.submissionMode = submissionMode

		uiView.isHidden = !isEnabled
		uiView.isUserInteractionEnabled = isEnabled

		// CRITICAL:
		// Never auto-focus on launch. Only focus when explicitly enabled and requested.
		// Keeping it unfocused prevents the software keyboard from appearing.
		if !isEnabled, uiView.isFirstResponder {
			uiView.resignFirstResponder()
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(gameLoop: gameLoop, submissionMode: submissionMode)
	}

	final class Coordinator: NSObject, UITextFieldDelegate {

		var gameLoop: GameLoop
		var submissionMode: SubmissionMode

		private var buffer: String = ""

		init(gameLoop: GameLoop, submissionMode: SubmissionMode) {
			self.gameLoop = gameLoop
			self.submissionMode = submissionMode
		}

		func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
			// Handle backspace
			if string.isEmpty {
				if !buffer.isEmpty {
					buffer.removeLast()
				}
				return false
			}

			// Some input methods deliver newline or return
			if string == "\n" {
				if submissionMode == .submitKey {
					submitBuffer(moleId: gameLoop.currentMoleId)
				}
				return false
			}

			// Collect input
			buffer.append(string)

			switch submissionMode {
			case .immediate:
				emitImmediateTokens(moleId: gameLoop.currentMoleId)
			case .submitKey:
				// Do nothing until return/submit
				break
			}

			return false
		}

		private func emitImmediateTokens(moleId: Int) {
			// Emit the most recent character only for immediate mode.
			// This mirrors the web "instant attempt" behavior.
			guard let last = buffer.last else { return }
			let attempt = Attempt(
				moleId: moleId,
				type: .brailleText,
				dotMask: nil,
				key: nil,
				char: String(last)
			)
			gameLoop.handleAttempt(attempt)
		}

		private func submitBuffer(moleId: Int) {
			let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
			buffer = ""

			guard !trimmed.isEmpty else { return }

			// Submit full buffer as a single attempt
			let attempt = Attempt(
				moleId: moleId,
				type: .brailleText,
				dotMask: nil,
				key: nil,
				char: trimmed
			)
			gameLoop.handleAttempt(attempt)
		}
	}

	final class NoKeyboardTextField: UITextField {

		// CRITICAL:
		// This suppresses the on-screen keyboard even if the field becomes first responder.
		override var inputView: UIView? {
			get { UIView(frame: .zero) }
			set { }
		}

		// Optional: remove input assistant bar
		override var inputAssistantItem: UITextInputAssistantItem {
			let item = super.inputAssistantItem
			item.leadingBarButtonGroups = []
			item.trailingBarButtonGroups = []
			return item
		}
	}
}


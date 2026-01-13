import UIKit

enum InputSubmissionMode {
	case immediate
	case submitKey
}

final class BrailleTextInputSink: UITextView, UITextViewDelegate {

	var onTextToken: ((String) -> Void)?

	var submissionMode: InputSubmissionMode = .immediate

	private var pendingTokens: [String] = []
	private var isInternallyResetting: Bool = false

	override var canBecomeFirstResponder: Bool {
		true
	}

	override func didMoveToWindow() {
		super.didMoveToWindow()
		becomeFirstResponder()
	}

	override init(frame: CGRect, textContainer: NSTextContainer?) {
		super.init(frame: frame, textContainer: textContainer)
		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	private func setup() {
		delegate = self

		isEditable = true
		isSelectable = true

		autocorrectionType = .no
		spellCheckingType = .no
		smartQuotesType = .no
		smartDashesType = .no
		smartInsertDeleteType = .no
		keyboardType = .default
		textContentType = nil
		returnKeyType = .default

		backgroundColor = .clear
		textColor = .clear
		tintColor = .clear

		isAccessibilityElement = false
		accessibilityElementsHidden = true
	}

	// MARK: - UITextViewDelegate

	func textView(
		_ textView: UITextView,
		shouldChangeTextIn range: NSRange,
		replacementText text: String
	) -> Bool {
		if isInternallyResetting {
			return true
		}

		// Submit keys (Enter / Return / dot 8 on many displays)
		if text == "\n" || text == "\r" {
			emitSubmitAttempt()
			return false
		}

		// In submit-key mode, treat space as submit (common for contracted braille)
		if submissionMode == .submitKey && text == " " {
			emitSubmitAttempt()
			return false
		}

		// Normal character input
		if !text.isEmpty {
			bufferTokens(from: text)

			if submissionMode == .immediate {
				emitImmediateAttempts(from: text)
			}
		}

		return true
	}

	func textViewDidChange(_ textView: UITextView) {
		if isInternallyResetting {
			return
		}

		// In immediate mode, clear shortly after change
		// to allow VoiceOver to echo the character
		if submissionMode == .immediate {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
				self?.resetBuffer()
			}
		}
	}

	// MARK: - Token handling

	private func bufferTokens(from text: String) {
		for scalar in text {
			let token = String(scalar)
			if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				continue
			}
			pendingTokens.append(token)
		}
	}

	private func emitImmediateAttempts(from text: String) {
		for scalar in text {
			let token = String(scalar)
			if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				continue
			}
			onTextToken?(token)
		}
	}

	private func emitSubmitAttempt() {
		guard let token = pendingTokens.last else {
			resetBuffer()
			return
		}

		onTextToken?(token)
		resetBuffer()
	}

	private func resetBuffer() {
		isInternallyResetting = true
		text = ""
		pendingTokens.removeAll()
		isInternallyResetting = false
	}
}


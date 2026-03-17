import SwiftUI
import UIKit

struct BrailleTextInputSinkView: UIViewRepresentable {

	enum SubmissionMode {
		case immediate
		case submitKey
	}

	let gameLoop: GameLoop
	let inputMode: InputMode
	let isEnabled: Bool
	let submissionMode: SubmissionMode

	func makeUIView(context: Context) -> GameInputTextField {
		let textField = GameInputTextField()
		textField.delegate = context.coordinator
		textField.borderStyle = .roundedRect
		textField.clearButtonMode = .never
		textField.autocorrectionType = .no
		textField.spellCheckingType = .no
		textField.smartQuotesType = .no
		textField.smartDashesType = .no
		textField.smartInsertDeleteType = .no
		textField.keyboardType = .default
		textField.returnKeyType = .done
		textField.enablesReturnKeyAutomatically = false
		textField.placeholder = "Braille and keyboard input"
		textField.backgroundColor = UIColor.secondarySystemBackground

		textField.onPerkinsChord = { [weak coordinator = context.coordinator] dotMask in
			coordinator?.emitPerkinsAttempt(dotMask: dotMask)
		}

		textField.onRepeatTarget = { [weak coordinator = context.coordinator] in
			coordinator?.gameLoop.repeatCurrentTarget()
		}

		return textField
	}

	func updateUIView(_ uiView: GameInputTextField, context: Context) {
		context.coordinator.gameLoop = gameLoop
		context.coordinator.inputMode = inputMode
		context.coordinator.submissionMode = submissionMode

		uiView.inputModeSelection = inputMode
		uiView.submissionMode = submissionMode
		uiView.isEnabled = isEnabled
		uiView.alpha = isEnabled ? 1.0 : 0.5

		if isEnabled, uiView.window != nil, !uiView.isFirstResponder {
			DispatchQueue.main.async {
				uiView.becomeFirstResponder()
			}
		} else if !isEnabled, uiView.isFirstResponder {
			uiView.resignFirstResponder()
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(
			gameLoop: gameLoop,
			inputMode: inputMode,
			submissionMode: submissionMode
		)
	}

	final class Coordinator: NSObject, UITextFieldDelegate {

		var gameLoop: GameLoop
		var inputMode: InputMode
		var submissionMode: SubmissionMode

		private var bufferedText: String = ""

		init(gameLoop: GameLoop, inputMode: InputMode, submissionMode: SubmissionMode) {
			self.gameLoop = gameLoop
			self.inputMode = inputMode
			self.submissionMode = submissionMode
		}

		func textField(
			_ textField: UITextField,
			shouldChangeCharactersIn range: NSRange,
			replacementString string: String
		) -> Bool {
			if string.isEmpty {
				if !bufferedText.isEmpty {
					bufferedText.removeLast()
				}
				return false
			}

			if string == "\n" || string == "\r" {
				submitBufferedText()
				return false
			}

			if string == "`" {
				gameLoop.repeatCurrentTarget()
				return false
			}

			if submissionMode == .submitKey && string == " " {
				submitBufferedText()
				return false
			}

			let tokens = tokenize(string)
			guard !tokens.isEmpty else { return false }

			if inputMode == .perkins, tokens.allSatisfy({ PerkinsKeyMapper.dot(forKey: $0) != nil }) {
				textField.text = ""
				return false
			}

			switch submissionMode {
			case .immediate:
				for token in tokens {
					emitImmediateAttempt(token: token)
				}
			case .submitKey:
				bufferedText.append(tokens.joined())
			}

			textField.text = ""
			return false
		}

		func emitPerkinsAttempt(dotMask: Int) {
			let attempt = Attempt(
				moleId: gameLoop.currentMoleId,
				type: .perkins,
				dotMask: dotMask,
				key: nil,
				char: nil
			)
			gameLoop.handleAttempt(attempt)
		}

		private func emitImmediateAttempt(token: String) {
			let attempt = Attempt(
				moleId: gameLoop.currentMoleId,
				type: attemptTypeForCurrentMode(),
				dotMask: nil,
				key: inputMode == .qwerty ? token : nil,
				char: inputMode == .qwerty ? nil : token
			)
			gameLoop.handleAttempt(attempt)
		}

		private func submitBufferedText() {
			let normalized = bufferedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			bufferedText = ""

			guard !normalized.isEmpty else { return }

			let attempt = Attempt(
				moleId: gameLoop.currentMoleId,
				type: .brailleText,
				dotMask: nil,
				key: nil,
				char: normalized
			)
			gameLoop.handleAttempt(attempt)
		}

		private func tokenize(_ string: String) -> [String] {
			string
				.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
				.filter { !$0.isEmpty }
		}

		private func attemptTypeForCurrentMode() -> InputMode {
			inputMode == .qwerty ? .qwerty : .brailleText
		}
	}

	final class GameInputTextField: UITextField {

		var inputModeSelection: InputMode = .qwerty
		var submissionMode: SubmissionMode = .immediate
		var onPerkinsChord: ((Int) -> Void)?
		var onRepeatTarget: (() -> Void)?

		private var activePerkinsKeys: Set<String> = []
		private var usedPerkinsKeys: Set<String> = []

		override var canBecomeFirstResponder: Bool {
			true
		}

		override var inputAssistantItem: UITextInputAssistantItem {
			let item = super.inputAssistantItem
			item.leadingBarButtonGroups = []
			item.trailingBarButtonGroups = []
			return item
		}

		override func didMoveToWindow() {
			super.didMoveToWindow()

			if isEnabled, window != nil {
				DispatchQueue.main.async {
					self.becomeFirstResponder()
				}
			}
		}

		override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
			var handledPerkins = false

			for press in presses {
				guard let key = press.key else { continue }
				let input = key.charactersIgnoringModifiers.lowercased()

				if input == "`" {
					onRepeatTarget?()
					continue
				}

				guard inputModeSelection == .perkins else { continue }

				if PerkinsKeyMapper.dot(forKey: input) != nil {
					activePerkinsKeys.insert(input)
					usedPerkinsKeys.insert(input)
					handledPerkins = true
				}
			}

			if !handledPerkins {
				super.pressesBegan(presses, with: event)
			}
		}

		override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
			var handledPerkins = false

			for press in presses {
				guard let key = press.key else { continue }
				let input = key.charactersIgnoringModifiers.lowercased()

				guard inputModeSelection == .perkins else { continue }

				if PerkinsKeyMapper.dot(forKey: input) != nil {
					activePerkinsKeys.remove(input)
					handledPerkins = true
				}
			}

			if handledPerkins, activePerkinsKeys.isEmpty, !usedPerkinsKeys.isEmpty {
				let dots = Set(usedPerkinsKeys.compactMap { PerkinsKeyMapper.dot(forKey: $0) })
				let dotMask = PerkinsKeyMapper.mask(forDots: dots)
				usedPerkinsKeys.removeAll()

				if dotMask != 0 {
					onPerkinsChord?(dotMask)
				}
			}

			if !handledPerkins {
				super.pressesEnded(presses, with: event)
			}
		}

		override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
			activePerkinsKeys.removeAll()
			usedPerkinsKeys.removeAll()
			super.pressesCancelled(presses, with: event)
		}
	}
}

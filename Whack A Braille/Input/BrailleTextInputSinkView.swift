import SwiftUI
import UIKit

struct BrailleTextInputSinkView: UIViewRepresentable {

	let gameLoop: GameLoop
	let inputMode: InputMode
	let isEnabled: Bool
	let autoFocus: Bool

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
		textField.placeholder = "Game input"
		textField.backgroundColor = UIColor.secondarySystemBackground
		textField.accessibilityTraits.insert(.allowsDirectInteraction)
		textField.accessibilityLabel = "Game input"
		textField.accessibilityHint = "Use Braille Screen Input, a keyboard, or a connected braille display."

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

		uiView.inputModeSelection = inputMode
		uiView.isEnabled = isEnabled
		uiView.alpha = isEnabled ? 1.0 : 0.45

		if isEnabled, autoFocus, uiView.window != nil, !uiView.isFirstResponder {
			DispatchQueue.main.async {
				uiView.becomeFirstResponder()
			}
		} else if !isEnabled, uiView.isFirstResponder {
			uiView.resignFirstResponder()
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(gameLoop: gameLoop, inputMode: inputMode)
	}

	final class Coordinator: NSObject, UITextFieldDelegate {

		var gameLoop: GameLoop
		var inputMode: InputMode

		init(gameLoop: GameLoop, inputMode: InputMode) {
			self.gameLoop = gameLoop
			self.inputMode = inputMode
		}

		func textField(
			_ textField: UITextField,
			shouldChangeCharactersIn range: NSRange,
			replacementString string: String
		) -> Bool {
			if string.isEmpty {
				return false
			}

			if string == "\n" || string == "\r" {
				return false
			}

			if string == "`" {
				gameLoop.repeatCurrentTarget()
				textField.text = ""
				return false
			}

			if string.count > 1 {
				let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
				if !normalized.isEmpty {
					let attempt = Attempt(
						moleId: gameLoop.currentMoleId,
						type: .brailleText,
						dotMask: nil,
						key: nil,
						char: normalized
					)
					gameLoop.handleAttempt(attempt)
				}
				textField.text = ""
				return false
			}

			let tokens = tokenize(string)
			guard !tokens.isEmpty else { return false }

			if inputMode == .perkins, tokens.allSatisfy({ PerkinsKeyMapper.dot(forKey: $0) != nil }) {
				textField.text = ""
				return false
			}

			for token in tokens {
				emitImmediateAttempt(token: token)
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
				type: inputMode == .qwerty ? .qwerty : .brailleText,
				dotMask: nil,
				key: inputMode == .qwerty ? token : nil,
				char: inputMode == .qwerty ? nil : token
			)
			gameLoop.handleAttempt(attempt)
		}

		private func tokenize(_ string: String) -> [String] {
			string
				.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
				.filter { !$0.isEmpty }
		}
	}

	final class GameInputTextField: UITextField {

		var inputModeSelection: InputMode = .qwerty
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

		override func accessibilityActivate() -> Bool {
			becomeFirstResponder()
			return true
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

import SwiftUI
import UIKit

extension Notification.Name {
	static let dismissGameplayInput = Notification.Name("dismissGameplayInput")
}

struct BrailleTextInputSinkView: UIViewRepresentable {

	let gameLoop: GameLoop
	let inputMode: InputMode
	let isEnabled: Bool
	let autoFocus: Bool
	let resetToken: Int

	func makeUIView(context: Context) -> GameInputTextField {
		let textField = GameInputTextField()
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
		textField.textContentType = .none
		textField.backgroundColor = UIColor.secondarySystemBackground
		textField.accessibilityLabel = "Braille Entry"
		textField.addTarget(textField, action: #selector(GameInputTextField.handleEditingChanged), for: .editingChanged)

		textField.onPerkinsChord = { [weak coordinator = context.coordinator] dotMask in
			coordinator?.emitPerkinsAttempt(dotMask: dotMask)
		}

		textField.onRepeatTarget = { [weak coordinator = context.coordinator] in
			coordinator?.gameLoop.repeatCurrentTarget()
		}

		textField.onTextInput = { [weak coordinator = context.coordinator] text in
			coordinator?.handleTextInput(text)
		}
		textField.onBufferedSubmit = { [weak coordinator = context.coordinator] text in
			coordinator?.handleTextInput(text)
		}

		return textField
	}

	func updateUIView(_ uiView: GameInputTextField, context: Context) {
		context.coordinator.gameLoop = gameLoop
		context.coordinator.inputMode = inputMode

		uiView.inputModeSelection = inputMode
		uiView.isAccessibilityElement = inputMode == .brailleText
		uiView.accessibilityElementsHidden = inputMode != .brailleText
		uiView.isEnabled = isEnabled
		uiView.alpha = isEnabled ? 1.0 : 0.45
		uiView.shouldAutoFocus = isEnabled && autoFocus
		uiView.applyResetToken(resetToken)
		uiView.attemptFocusIfNeeded()

		if !isEnabled, uiView.isFirstResponder {
			uiView.resignFirstResponder()
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(gameLoop: gameLoop, inputMode: inputMode)
	}

	static func dismantleUIView(_ uiView: GameInputTextField, coordinator: Coordinator) {
		uiView.shouldAutoFocus = false
		uiView.clearForTransition()
		if uiView.isFirstResponder {
			uiView.resignFirstResponder()
		}
	}

	final class Coordinator: NSObject {

		var gameLoop: GameLoop
		var inputMode: InputMode

		init(gameLoop: GameLoop, inputMode: InputMode) {
			self.gameLoop = gameLoop
			self.inputMode = inputMode
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

		func handleTextInput(_ text: String) {
			let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			guard !normalized.isEmpty else { return }

			if normalized == "`" {
				gameLoop.repeatCurrentTarget()
				return
			}

			if inputMode == .perkins && normalized.count == 1, PerkinsKeyMapper.dot(forKey: normalized) != nil {
				return
			}

			if normalized.count > 1 {
				let attempt = Attempt(
					moleId: gameLoop.currentMoleId,
					type: .brailleText,
					dotMask: nil,
					key: nil,
					char: normalized
				)
				gameLoop.handleAttempt(attempt)
				return
			}

			for token in tokenize(normalized) {
				emitImmediateAttempt(token: token)
			}
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
		var shouldAutoFocus = false
		var onPerkinsChord: ((Int) -> Void)?
		var onRepeatTarget: (() -> Void)?
		var onTextInput: ((String) -> Void)?
		var onBufferedSubmit: ((String) -> Void)?

		private var activePerkinsKeys: Set<String> = []
		private var usedPerkinsKeys: Set<String> = []
		private var focusAttemptCount = 0
		private var lastResetToken = -1
		private var suppressedInsertText: String?
		private var suppressInsertTextUntil = 0.0
		private var dismissObserver: NSObjectProtocol?

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
			_ = becomeFirstResponder()
			return true
		}

		override func didMoveToWindow() {
			super.didMoveToWindow()

			if window != nil, dismissObserver == nil {
				dismissObserver = NotificationCenter.default.addObserver(
					forName: .dismissGameplayInput,
					object: nil,
					queue: .main
				) { [weak self] _ in
					guard let self else { return }
					self.shouldAutoFocus = false
					self.clearBufferedText()
					self.window?.endEditing(true)
					self.reloadInputViews()
					if self.isFirstResponder {
						self.resignFirstResponder()
					}
				}
			}

			if window == nil, let dismissObserver {
				NotificationCenter.default.removeObserver(dismissObserver)
				self.dismissObserver = nil
			}

			attemptFocusIfNeeded()
		}

		deinit {
			if let dismissObserver {
				NotificationCenter.default.removeObserver(dismissObserver)
			}
		}

		override func becomeFirstResponder() -> Bool {
			let becameFirstResponder = super.becomeFirstResponder()
			if becameFirstResponder {
				focusAttemptCount = 0
			}
			return becameFirstResponder
		}

		override func insertText(_ text: String) {
			if text == "\n" || text == "\r" || text == " " {
				submitBufferedText()
				return
			}

			if inputModeSelection == .brailleText {
				super.insertText(text)
				return
			}

			let now = Date.timeIntervalSinceReferenceDate
			if suppressedInsertText == text.lowercased(), now <= suppressInsertTextUntil {
				return
			}

			onTextInput?(text)
			clearBufferedText()
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

				for press in presses {
					guard let key = press.key else { continue }
					let input = key.charactersIgnoringModifiers.lowercased()

					if inputModeSelection == .brailleText {
						if input == " " || input == "\n" || input == "\r" {
							submitBufferedText()
						}
						continue
					}

					if input == " " || input == "\n" || input == "\r" {
						continue
					}

					guard input.count == 1 else { continue }
					suppressedInsertText = input
					suppressInsertTextUntil = Date.timeIntervalSinceReferenceDate + 0.2
					onTextInput?(input)
					clearBufferedText()
				}
			}
		}

		override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
			activePerkinsKeys.removeAll()
			usedPerkinsKeys.removeAll()
			super.pressesCancelled(presses, with: event)
		}

		func attemptFocusIfNeeded() {
			guard shouldAutoFocus, window != nil, !isFirstResponder else { return }
			guard focusAttemptCount < 8 else { return }

			focusAttemptCount += 1

			DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
				guard let self else { return }
				guard self.shouldAutoFocus, self.window != nil, !self.isFirstResponder else { return }
				_ = self.becomeFirstResponder()
				self.attemptFocusIfNeeded()
			}
		}

		func applyResetToken(_ token: Int) {
			guard token != lastResetToken else { return }
			lastResetToken = token
			suppressedInsertText = nil
			suppressInsertTextUntil = 0
			clearBufferedText()
		}

		func clearForTransition() {
			suppressedInsertText = nil
			suppressInsertTextUntil = 0
			activePerkinsKeys.removeAll()
			usedPerkinsKeys.removeAll()
			clearBufferedText()
			window?.endEditing(true)
			reloadInputViews()
		}

		@objc
		func handleEditingChanged() {
			let buffered = currentBufferedText()

			if inputModeSelection == .brailleText {
				guard buffered.contains(where: \.isWhitespace) else { return }
				submitBufferedText()
				return
			}

			let normalized = buffered.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			guard let token = normalized.last.map(String.init), !token.isEmpty else { return }

			let now = Date.timeIntervalSinceReferenceDate
			if suppressedInsertText == token, now <= suppressInsertTextUntil {
				clearBufferedText()
				return
			}

			onTextInput?(token)
			clearBufferedText()
		}

		func submitBufferedText() {
			let submitted = currentBufferedText().trimmingCharacters(in: .whitespacesAndNewlines)
			clearBufferedText()

			guard !submitted.isEmpty else { return }
			onBufferedSubmit?(submitted)
		}

		private func currentBufferedText() -> String {
			if let fullRange = textRange(from: beginningOfDocument, to: endOfDocument),
				let documentText = text(in: fullRange),
				!documentText.isEmpty {
				return documentText
			}

			return text ?? ""
		}

		private func clearBufferedText() {
			unmarkText()

			if let fullRange = textRange(from: beginningOfDocument, to: endOfDocument) {
				replace(fullRange, withText: "")
			}

			text = ""
			selectedTextRange = textRange(from: beginningOfDocument, to: beginningOfDocument)
		}
	}
}

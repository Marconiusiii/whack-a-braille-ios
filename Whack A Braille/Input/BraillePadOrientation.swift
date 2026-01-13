import UIKit

enum BraillePadOrientation {
	case tabletop
	case screenAway
}

final class BraillePadTouchView: UIView {

	var orientation: BraillePadOrientation = .tabletop
	var onChord: ((Int) -> Void)?

	private var activeDots: Set<Int> = []

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	private func commonInit() {
		isMultipleTouchEnabled = true
		backgroundColor = .clear
		isAccessibilityElement = false
		accessibilityElementsHidden = true
		accessibilityTraits.insert(.allowsDirectInteraction)
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		updateDotsFromEvent(event)
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		updateDotsFromEvent(event)
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		updateDotsFromEvent(event)
		if allTouchesEnded(event) {
			emitChord()
		}
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		activeDots.removeAll()
	}

	private func updateDotsFromEvent(_ event: UIEvent?) {
		activeDots.removeAll()
		guard let event else { return }

		for touch in event.allTouches ?? [] {
			switch touch.phase {
			case .began, .moved, .stationary:
				let p = touch.location(in: self)
				if let dot = dotForPoint(p) {
					activeDots.insert(dot)
				}
			default:
				continue
			}
		}
	}

	private func allTouchesEnded(_ event: UIEvent?) -> Bool {
		guard let event else { return true }
		for touch in event.allTouches ?? [] {
			switch touch.phase {
			case .began, .moved, .stationary:
				return false
			default:
				continue
			}
		}
		return true
	}

	private func emitChord() {
		let mask = dotsToMask(activeDots)
		activeDots.removeAll()
		if mask != 0 {
			onChord?(mask)
		}
	}

	private func dotsToMask(_ dots: Set<Int>) -> Int {
		var mask = 0
		for dot in dots {
			mask |= 1 << (dot - 1)
		}
		return mask
	}

	private func dotForPoint(_ p: CGPoint) -> Int? {
		let w = bounds.width
		let h = bounds.height
		if w <= 0 || h <= 0 { return nil }

		let col = (p.x < w / 2) ? 0 : 1
		let rowHeight = h / 3
		let row = min(2, max(0, Int(p.y / rowHeight)))

		let leftCol = [1, 2, 3]
		let rightCol = [4, 5, 6]

		switch orientation {
		case .tabletop:
			return (col == 0) ? leftCol[row] : rightCol[row]
		case .screenAway:
			return (col == 0) ? rightCol[row] : leftCol[row]
		}
	}
}

import UIKit


final class BraillePadTouchView: UIView {

	var orientation: BraillePadOrientation = .tabletop
	var onChord: ((Int) -> Void)?

	private let calibration = BraillePadCalibration()
	private var calibrationResult: BraillePadCalibrationResult? = BraillePadCalibrationStore.shared.load()

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
		handleCalibrationIfNeeded(event: event)
		updateDotsFromEvent(event)
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		handleCalibrationIfNeeded(event: event)
		updateDotsFromEvent(event)
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		handleCalibrationIfNeeded(event: event)
		updateDotsFromEvent(event)
		if allTouchesEnded(event) {
			emitChord()
		}
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		activeDots.removeAll()
	}

	private func handleCalibrationIfNeeded(event: UIEvent?) {
		let now = Int(Date().timeIntervalSince1970 * 1000.0)
		let touchesArray = Array(event?.allTouches ?? [])

		if let result = calibration.processTouches(
			activeTouches: touchesArray,
			in: self,
			nowMs: now
		) {
			calibrationResult = result
			BraillePadCalibrationStore.shared.save(result)
			SpeechEngine.shared.speak("Calibrated")
			activeDots.removeAll()
		}
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
		if let calib = calibrationResult {
			let nearest = calib.dotCenters.min {
				hypot($0.value.x - p.x, $0.value.y - p.y) <
				hypot($1.value.x - p.x, $1.value.y - p.y)
			}
			return nearest?.key
		}

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
//
//  BraillePadTouchView.swift
//  Whack A Braille
//
//  Created by Marco Salsiccia on 1/13/26.
//


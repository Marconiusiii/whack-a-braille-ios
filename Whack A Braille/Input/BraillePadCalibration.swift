import UIKit

struct BraillePadCalibrationResult: Codable {
	let dotCenters: [Int: CGPoint]
	let timestamp: TimeInterval
}

final class BraillePadCalibration {

	private enum State {
		case idle
		case rightHandDown(startMs: Int, rightPoints: [CGPoint])
		case waitingForLeft(maxUntilMs: Int, rightPoints: [CGPoint])
	}

	private var state: State = .idle

	private let minRightHoldMs: Int = 120
	private let maxGapMs: Int = 500

	func processTouches(
		activeTouches: [UITouch],
		in view: UIView,
		nowMs: Int
	) -> BraillePadCalibrationResult? {

		let points = activeTouches
			.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }
			.map { $0.location(in: view) }

		switch state {
		case .idle:
			if points.count == 3 {
				state = .rightHandDown(startMs: nowMs, rightPoints: points)
			}

		case .rightHandDown(let startMs, let rightPoints):
			if points.isEmpty {
				let heldMs = nowMs - startMs
				if heldMs >= minRightHoldMs {
					state = .waitingForLeft(
						maxUntilMs: nowMs + maxGapMs,
						rightPoints: rightPoints
					)
				} else {
					state = .idle
				}
			} else if points.count != 3 {
				state = .idle
			}

		case .waitingForLeft(let maxUntilMs, let rightPoints):
			if nowMs > maxUntilMs {
				state = .idle
				return nil
			}

			if points.count == 3 {
				let result = buildResult(left: points, right: rightPoints)
				state = .idle
				return result
			} else if points.count != 0 {
				state = .idle
			}
		}

		return nil
	}

	private func buildResult(left: [CGPoint], right: [CGPoint]) -> BraillePadCalibrationResult {
		func sortByY(_ pts: [CGPoint]) -> [CGPoint] {
			pts.sorted { $0.y < $1.y }
		}

		let leftSorted = sortByY(left)
		let rightSorted = sortByY(right)

		var map: [Int: CGPoint] = [:]
		map[1] = leftSorted[0]
		map[2] = leftSorted[1]
		map[3] = leftSorted[2]
		map[4] = rightSorted[0]
		map[5] = rightSorted[1]
		map[6] = rightSorted[2]

		return BraillePadCalibrationResult(
			dotCenters: map,
			timestamp: Date().timeIntervalSince1970
		)
	}
}

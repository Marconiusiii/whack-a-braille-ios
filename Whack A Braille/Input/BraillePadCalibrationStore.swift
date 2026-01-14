import Foundation
import CoreGraphics

final class BraillePadCalibrationStore {

	static let shared = BraillePadCalibrationStore()

	private let key = "whackABraille.touchPadCalibration.v1"

	private init() {}

	func save(_ result: BraillePadCalibrationResult) {
		if let data = try? JSONEncoder().encode(result) {
			UserDefaults.standard.set(data, forKey: key)
		}
	}

	func load() -> BraillePadCalibrationResult? {
		guard
			let data = UserDefaults.standard.data(forKey: key),
			let result = try? JSONDecoder().decode(BraillePadCalibrationResult.self, from: data)
		else {
			return nil
		}
		return result
	}

	func clear() {
		UserDefaults.standard.removeObject(forKey: key)
	}
}


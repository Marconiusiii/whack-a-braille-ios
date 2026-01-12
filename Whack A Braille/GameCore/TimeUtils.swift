import Foundation

enum TimeUtils {

	static func nowMs() -> Int {
		Int(Date().timeIntervalSince1970 * 1000)
	}

	static func lerp(start: Int, end: Int, t: Double) -> Int {
		Int(Double(start) + (Double(end - start) * t))
	}
}

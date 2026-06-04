//
//  Whack_A_BrailleApp.swift
//  Whack A Braille
//
//  Created by Marco Salsiccia on 1/12/26.
//

import SwiftUI
#if canImport(DeclaredAgeRange)
import DeclaredAgeRange
#endif

@main
struct Whack_A_BrailleApp: App {
	var body: some Scene {
		WindowGroup {
			GameView()
				.background {
					AgeAssuranceComplianceView()
				}
		}
	}
}

private struct AgeAssuranceComplianceView: View {
	var body: some View {
		if #available(iOS 26.0, *) {
			DeclaredAgeRangeComplianceTask()
		}
	}
}

#if canImport(DeclaredAgeRange)
@available(iOS 26.0, *)
private struct DeclaredAgeRangeComplianceTask: View {
	@Environment(\.requestAgeRange) private var requestAgeRange
	@State private var hasCheckedAgeRange = false

	var body: some View {
		Color.clear
			.frame(width: 0, height: 0)
			.accessibilityHidden(true)
			.task {
				await checkDeclaredAgeRangeIfRequired()
			}
	}

	private func checkDeclaredAgeRangeIfRequired() async {
		guard !hasCheckedAgeRange else { return }
		hasCheckedAgeRange = true

		do {
			if #available(iOS 26.4, *) {
				let features = try await AgeRangeService.shared.requiredRegulatoryFeatures
				guard features.contains(.declaredAgeRangeRequired) else { return }
			} else if #available(iOS 26.2, *) {
				let isEligible = try await AgeRangeService.shared.isEligibleForAgeFeatures
				guard isEligible else { return }
			}

			_ = try await requestAgeRange(ageGates: 13, 16, 18)
		} catch {
			// Age range sharing is platform-managed and optional outside required regions.
		}
	}
}
#else
@available(iOS 26.0, *)
private struct DeclaredAgeRangeComplianceTask: View {
	var body: some View {
		EmptyView()
	}
}
#endif

import Combine
import Foundation
import StoreKit

@MainActor
final class SupportStore: ObservableObject {

	enum SupportStatus: Equatable {
		case idle
		case loading
		case purchasing(String)
		case success(String)
		case pending
		case failed(String)
	}

	struct SupportOption: Identifiable, Equatable {
		let productID: String
		let fallbackName: String
		let fallbackPrice: String
		let fanfareTier: PrizeTier

		var id: String { productID }
	}

	struct SupportThankYou: Equatable {
		let supportName: String
		let date: Date
	}

	static let shared = SupportStore()

	static let supportOptions: [SupportOption] = [
		SupportOption(
			productID: "com.marconius.whackabraille.support.lightthwap",
			fallbackName: "Light Thwap",
			fallbackPrice: "$0.99",
			fanfareTier: .tier3
		),
		SupportOption(
			productID: "com.marconius.whackabraille.support.bigbonk",
			fallbackName: "Big Bonk",
			fallbackPrice: "$1.99",
			fanfareTier: .tier4
		),
		SupportOption(
			productID: "com.marconius.whackabraille.support.megawhack",
			fallbackName: "Mega Whack",
			fallbackPrice: "$2.99",
			fanfareTier: .tier5
		),
		SupportOption(
			productID: "com.marconius.whackabraille.support.ultimatewhackage",
			fallbackName: "Ultimate Whackage",
			fallbackPrice: "$4.99",
			fanfareTier: .tier6
		)
	]

	@Published private(set) var products: [Product] = []
	@Published private(set) var status: SupportStatus = .idle
	@Published private(set) var latestThankYou: SupportThankYou?

	private enum StorageKey {
		static let supportName = "whackABraille.support.latestName"
		static let supportDate = "whackABraille.support.latestDate"
	}

	private init() {
		loadStoredThankYou()
	}

	func loadProducts() async {
		guard products.isEmpty else { return }
		status = .loading

		do {
			let productIDs = Self.supportOptions.map(\.productID)
			let loadedProducts = try await Product.products(for: productIDs)
			products = loadedProducts.sorted { lhs, rhs in
				optionIndex(for: lhs.id) < optionIndex(for: rhs.id)
			}
			status = .idle
		} catch {
			status = .failed("The prize counter could not load support options.")
		}
	}

	func product(for option: SupportOption) -> Product? {
		products.first { $0.id == option.productID }
	}

	func purchase(_ option: SupportOption) async {
		guard let product = product(for: option) else {
			status = .failed("The token slot is not ready yet.")
			return
		}

		status = .purchasing(option.fallbackName)

		do {
			let result = try await product.purchase()

			switch result {
			case .success(let verificationResult):
				let transaction = try checkVerified(verificationResult)
				await transaction.finish()
				recordSuccessfulSupport(option)
				status = .success(option.fallbackName)
				GameAudioEngine.shared.playPrizeFanfare(for: option.fanfareTier)
			case .pending:
				status = .pending
			case .userCancelled:
				status = .idle
			@unknown default:
				status = .failed("The token slot did something mysterious.")
			}
		} catch {
			status = .failed("The token slot jammed. No support went through.")
		}
	}

	func clearStatus() {
		status = .idle
	}

	private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
		switch result {
		case .verified(let value):
			return value
		case .unverified:
			throw StoreError.failedVerification
		}
	}

	private func recordSuccessfulSupport(_ option: SupportOption) {
		let date = Date()
		UserDefaults.standard.set(option.fallbackName, forKey: StorageKey.supportName)
		UserDefaults.standard.set(date, forKey: StorageKey.supportDate)
		latestThankYou = SupportThankYou(supportName: option.fallbackName, date: date)
	}

	private func loadStoredThankYou() {
		guard
			let supportName = UserDefaults.standard.string(forKey: StorageKey.supportName),
			let date = UserDefaults.standard.object(forKey: StorageKey.supportDate) as? Date
		else {
			return
		}

		latestThankYou = SupportThankYou(supportName: supportName, date: date)
	}

	private func optionIndex(for productID: String) -> Int {
		Self.supportOptions.firstIndex { $0.productID == productID } ?? Int.max
	}

	private enum StoreError: Error {
		case failedVerification
	}
}

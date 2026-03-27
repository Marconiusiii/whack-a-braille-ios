import Foundation

enum PrizeTier: Int {
	case tier1 = 1
	case tier2 = 2
	case tier3 = 3
	case tier4 = 4
	case tier5 = 5

	var detailLabel: String {
		switch self {
		case .tier1:
			return "Tier 1"
		case .tier2:
			return "Tier 2"
		case .tier3:
			return "Tier 3"
		case .tier4:
			return "Tier 4"
		case .tier5:
			return "Tier 5"
		}
	}
}

struct Prize: Identifiable, Equatable {
	let id: String
	let label: String
	let minTickets: Int
	let maxTickets: Int?
	let category: String
	let flavorText: String

	var ticketCost: Int {
		max(1, minTickets)
	}

	var tier: PrizeTier {
		if id.hasPrefix("tier1_") { return .tier1 }
		if id.hasPrefix("tier2_") { return .tier2 }
		if id.hasPrefix("tier3_") { return .tier3 }
		if id.hasPrefix("tier4_") { return .tier4 }
		if id.hasPrefix("tier5_") { return .tier5 }

		switch minTickets {
		case ..<10:
			return .tier1
		case ..<25:
			return .tier2
		case ..<50:
			return .tier3
		case ..<100:
			return .tier4
		default:
			return .tier5
		}
	}
}

struct PrizeShelfEntry: Codable, Equatable {
	let label: String
	var quantity: Int
	var latestClaimedAt: Date?

	init(label: String, quantity: Int, latestClaimedAt: Date? = nil) {
		self.label = label
		self.quantity = quantity
		self.latestClaimedAt = latestClaimedAt
	}

	private enum CodingKeys: String, CodingKey {
		case label
		case quantity
		case latestClaimedAt
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		label = try container.decode(String.self, forKey: .label)
		quantity = try container.decode(Int.self, forKey: .quantity)
		latestClaimedAt = try container.decodeIfPresent(Date.self, forKey: .latestClaimedAt)
	}
}

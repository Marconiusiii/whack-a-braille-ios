import Foundation

enum PrizeTier: Int {
	case tier1 = 1
	case tier2 = 2
	case tier3 = 3
	case tier4 = 4
	case tier5 = 5
}

struct Prize: Identifiable, Equatable {
	let id: String
	let label: String
	let minTickets: Int
	let maxTickets: Int?
	let category: String

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
}

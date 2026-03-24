import Foundation

struct Prize: Identifiable, Equatable {
	let id: String
	let label: String
	let minTickets: Int
	let maxTickets: Int?
	let category: String

	var ticketCost: Int {
		minTickets
	}
}

struct PrizeShelfEntry: Codable, Equatable {
	let label: String
	var quantity: Int
}

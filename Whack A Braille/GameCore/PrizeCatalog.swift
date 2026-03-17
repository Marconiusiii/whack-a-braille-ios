import Foundation

enum PrizeCatalog {

	static let all: [Prize] = [
		Prize(id: "tier1_invisibleMole", label: "One Invisible Stuffed Mole", minTickets: 0, maxTickets: 9, category: "joke"),
		Prize(id: "tier1_missedOpportunity", label: "A Missed Opportunity You Will Think About Later", minTickets: 0, maxTickets: 9, category: "joke"),
		Prize(id: "tier1_unlabeledButton", label: "An Unlabeled Button", minTickets: 0, maxTickets: 9, category: "meta"),
		Prize(id: "tier1_pocketSand", label: "Pocket Sand!", minTickets: 0, maxTickets: 9, category: "joke"),
		Prize(id: "tier1_tryingCertificate", label: "A Certificate of Trying Your Best", minTickets: 0, maxTickets: 9, category: "encouragement"),
		Prize(id: "tier1_staleGroundCoffee", label: "A half-empty bag of stale ground coffee", minTickets: 0, maxTickets: 9, category: "joke"),
		Prize(id: "tier2_nearWin", label: "Official Recognition of Being Very Close", minTickets: 10, maxTickets: 24, category: "encouragement"),
		Prize(id: "tier2_spokenLegend", label: "A Rumor That You Are Pretty Good at This", minTickets: 10, maxTickets: 24, category: "brag"),
		Prize(id: "tier2_slinky", label: "A Slightly Tangled Slinky", minTickets: 10, maxTickets: 24, category: "meta"),
		Prize(id: "tier2_moleWhistle", label: "A Golden Mole Whistle", minTickets: 10, maxTickets: 24, category: "joke"),
		Prize(id: "tier2_badge", label: "A Totally Legit Winner Badge", minTickets: 10, maxTickets: 24, category: "brag"),
		Prize(id: "tier2_burntBeans", label: "A Bag of Slightly Burnt Coffee Beans", minTickets: 10, maxTickets: 24, category: "joke"),
		Prize(id: "tier3_arcadeCape", label: "A Flowing Arcade Champion Cape", minTickets: 25, maxTickets: 49, category: "brag"),
		Prize(id: "tier3_whackDiploma", label: "An Official Diploma in Advanced Whacking", minTickets: 25, maxTickets: 49, category: "title"),
		Prize(id: "tier3_moleUnion", label: "Notice That the Moles Are Considering Unionizing", minTickets: 25, maxTickets: 49, category: "joke"),
		Prize(id: "tier3_arcadeJacket", label: "A braille-bedazzled Jacket That Definitely Says Arcade Legend", minTickets: 25, maxTickets: 49, category: "brag"),
		Prize(id: "tier3_goldSlinky", label: "A Golden Slinky", minTickets: 25, maxTickets: 49, category: "title"),
		Prize(id: "tier4_echoingName", label: "Your Name Echoed Dramatically Across the Arcade", minTickets: 50, maxTickets: 99, category: "absurd"),
		Prize(id: "tier4_arcadeMyth", label: "Arcade Myth Status (Stories May Be Exaggerated)", minTickets: 50, maxTickets: 99, category: "legend"),
		Prize(id: "tier4_applauseTrack", label: "A Looping Applause Track That Follows You", minTickets: 50, maxTickets: 99, category: "brag"),
		Prize(id: "tier4_grandMaster", label: "Grand Master of the Whack Arts", minTickets: 50, maxTickets: 99, category: "title"),
		Prize(id: "tier4_moleCommander", label: "Supreme Mole Commander", minTickets: 50, maxTickets: 99, category: "title"),
		Prize(id: "tier4_hallOfFame", label: "A Hall of Fame Induction (Unofficial)", minTickets: 50, maxTickets: 99, category: "brag"),
		Prize(id: "tier5_arcadeConstellation", label: "A Constellation Named After Your Whacking Technique", minTickets: 100, maxTickets: nil, category: "legend"),
		Prize(id: "tier5_arcadeImmortal", label: "Permanent Arcade Immortality (Locally Recognized)", minTickets: 100, maxTickets: nil, category: "legend"),
		Prize(id: "tier5_molePeaceTreaty", label: "A Historic Peace Treaty With the Moles", minTickets: 100, maxTickets: nil, category: "legend"),
		Prize(id: "tier5_infiniteTickets", label: "Infinite Tickets That You Are Asked Not to Redeem", minTickets: 100, maxTickets: nil, category: "legend"),
		Prize(id: "tier5_tokenBrick", label: "Platinum Token Brick", minTickets: 100, maxTickets: nil, category: "legend"),
		Prize(id: "tier5_hallJoystick", label: "Hall of Fame Joystick", minTickets: 100, maxTickets: nil, category: "legend"),
		Prize(id: "tier5_stylusSet", label: "Collector Edition Louis Braille Stylus Set", minTickets: 100, maxTickets: nil, category: "legend"),
		Prize(id: "tier5_guideDogSnacks2", label: "Premium Guide Dog Snacks", minTickets: 100, maxTickets: nil, category: "legend"),
		Prize(id: "tier5_glideTips", label: "Lifetime Supply of Metal Glide Tips", minTickets: 100, maxTickets: nil, category: "legend")
	]

	static func eligible(for ticketCount: Int) -> [Prize] {
		all.filter { prize in
			guard ticketCount >= prize.minTickets else { return false }
			if let maxTickets = prize.maxTickets, ticketCount > maxTickets {
				return false
			}
			return true
		}
	}
}

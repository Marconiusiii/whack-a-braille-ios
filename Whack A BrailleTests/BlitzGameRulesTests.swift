import Foundation
import XCTest
@testable import Whack_A_Braille

@MainActor
final class BlitzGameRulesTests: XCTestCase {

	private var repositoryRoot: URL {
		URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
	}

	private var blitzCatalogURL: URL {
		repositoryRoot.appending(path: "Whack A Braille/Resources/blitz-words-en.txt")
	}

	private var wordyMoleMayhemCatalogURL: URL {
		repositoryRoot.appending(path: "Whack A Braille/Resources/wordy-mole-mayhem-words-en.tsv")
	}

	private var wordyMoleMayhemExclusionsURL: URL {
		repositoryRoot.appending(path: "scripts/wordy-mole-mayhem-excluded-en.txt")
	}

	private var wordyMoleMayhemCommonWordsURL: URL {
		repositoryRoot.appending(path: "scripts/wordy-mole-mayhem-common-en.txt")
	}

	private var wordBopIOSSourceURL: URL {
		if let override = ProcessInfo.processInfo.environment["WORDBOP_IOS_WORDLIST_PATH"],
			!override.isEmpty {
			return URL(fileURLWithPath: override)
		}

		return repositoryRoot
			.deletingLastPathComponent()
			.appending(path: "wordBop-iOS/WordBop/WordBop/words-en.txt")
	}

	func testCatalogStructureSafetyAndCoverage() throws {
		let catalogContents = try contents(of: blitzCatalogURL)
		let wordyMoleMayhemCatalogContents = try contents(of: wordyMoleMayhemCatalogURL)
		let excludedWords = try wordSet(at: wordyMoleMayhemExclusionsURL)
		let commonWords = try wordSet(at: wordyMoleMayhemCommonWordsURL)
		let words = BlitzWordCatalog.words(from: catalogContents)
		let wordyMoleMayhemEntries = WordyMoleMayhemCatalog.entries(
			from: wordyMoleMayhemCatalogContents
		)

		XCTAssertTrue(
			BlitzWordCatalog.validationIssues(in: words).isEmpty,
			BlitzWordCatalog.validationIssues(in: words).joined(separator: "\n")
		)
		XCTAssertTrue(
			WordyMoleMayhemCatalog.validationIssues(in: wordyMoleMayhemEntries).isEmpty,
			WordyMoleMayhemCatalog.validationIssues(in: wordyMoleMayhemEntries).joined(separator: "\n")
		)
		XCTAssertGreaterThan(wordyMoleMayhemEntries.count, 20_000)
		XCTAssertTrue(wordyMoleMayhemEntries.allSatisfy { commonWords.contains($0.text) })
		XCTAssertTrue(wordyMoleMayhemEntries.allSatisfy { !excludedWords.contains($0.text) })

		let counts = Dictionary(grouping: words, by: \.length).mapValues(\.count)
		XCTAssertGreaterThan(counts[3, default: 0], 0)
		XCTAssertGreaterThan(counts[4, default: 0], 0)
		XCTAssertGreaterThan(counts[5, default: 0], 0)

		let mayhemCounts = Dictionary(grouping: wordyMoleMayhemEntries, by: \.length).mapValues(\.count)
		for length in 4...10 {
			XCTAssertGreaterThan(mayhemCounts[length, default: 0], 1_000)
		}
	}

	func testCatalogsComeFromWordBopIOSEnglishSourceWhenAvailable() throws {
		guard FileManager.default.fileExists(atPath: wordBopIOSSourceURL.path) else {
			throw XCTSkip(
				"WordBop iOS English source is not available. Set WORDBOP_IOS_WORDLIST_PATH to run provenance validation."
			)
		}

		let sourceWords = try wordSet(at: wordBopIOSSourceURL, includesComments: true)
		let battleWords = BlitzWordCatalog.words(from: try contents(of: blitzCatalogURL))
		let mayhemWords = WordyMoleMayhemCatalog.entries(
			from: try contents(of: wordyMoleMayhemCatalogURL)
		)

		XCTAssertTrue(battleWords.allSatisfy { sourceWords.contains($0.text) })
		XCTAssertTrue(mayhemWords.allSatisfy { sourceWords.contains($0.text) })
	}

	func testBattleModeRulesAndStereoPositions() {
		let customWords = ["cat", "book", "tunes"]

		XCTAssertTrue(
			BlitzWordCatalog.words(for: "grade1ThreeLetterBlitz", customWords: customWords)
				.allSatisfy { $0.length == 3 }
		)
		XCTAssertTrue(
			BlitzWordCatalog.words(for: "grade1FourLetterBlitz", customWords: customWords)
				.allSatisfy { $0.length == 4 }
		)
		XCTAssertEqual(BlitzWord.allowedLengths(for: "grade1MoleBlitz"), [3, 4, 5])
		XCTAssertEqual((0..<3).map { BlitzWord.pan(forLetterAt: $0, wordLength: 3) }, [-0.5, 0, 0.5])
		XCTAssertEqual((0..<4).map { BlitzWord.pan(forLetterAt: $0, wordLength: 4) }, [-0.75, -0.25, 0.25, 0.75])
		XCTAssertEqual((0..<5).map { BlitzWord.pan(forLetterAt: $0, wordLength: 5) }, [-1, -0.5, 0, 0.5, 1])

		let repeatedLetterItem = BlitzWord(text: "book").asBrailleItem(
			modeId: "grade1FourLetterBlitz"
		)
		XCTAssertEqual(repeatedLetterItem?.perkinsSequenceDots.count, 4)
		XCTAssertEqual(
			repeatedLetterItem?.perkinsSequenceDots[1],
			repeatedLetterItem?.perkinsSequenceDots[2]
		)
		XCTAssertEqual(repeatedLetterItem?.modeTags, ["grade1FourLetterBlitz"])
	}

	func testWordyMoleMayhemAcceptsContractedAndUncontractedPerkinsInput() throws {
		let entries = WordyMoleMayhemCatalog.entries(
			from: try contents(of: wordyMoleMayhemCatalogURL)
		)
		let knowledge = try XCTUnwrap(entries.first { $0.text == "knowledge" })

		XCTAssertEqual(knowledge.contractedMasks.count, 1)
		XCTAssertTrue(knowledge.acceptedPerkinsSequences.contains(knowledge.contractedMasks))
		XCTAssertTrue(knowledge.acceptedPerkinsSequences.contains(knowledge.uncontractedMasks))
		XCTAssertEqual(knowledge.asBrailleItem()?.acceptedTextInputs, ["knowledge"])
	}

	func testChooserGroupsAndInputDependentVisibility() {
		let qwertySections = BrailleRegistry.filteredModeSections(for: .qwerty)
		XCTAssertEqual(
			qwertySections.map(\.title),
			["Grade 1", "Grade 2", "Mole Battles", "Typing", "Custom"]
		)
		XCTAssertEqual(
			qwertySections.first(where: { $0.id == "typing" })?.options.map(\.label),
			[
				"Simple Home Row",
				"QWERTY Home Row",
				"QWERTY Home Row + Top Row",
				"QWERTY Home Row + Bottom Row"
			]
		)
		XCTAssertEqual(
			qwertySections.first(where: { $0.id == "moleBattles" })?.options.map(\.label),
			["3-Letter Words", "4-Letter Words", "Grade 1 Mole Battle", "Wordy Mole Mayhem"]
		)
		XCTAssertTrue(
			qwertySections.first(where: { $0.id == "grade2" })?
				.options.contains(where: { $0.id == "grade2Suffixes" }) == true
		)
		XCTAssertTrue(
			qwertySections.first(where: { $0.id == "grade2" })?
				.options.contains(where: { $0.id == "grade2Dot456Initials" }) == false
		)

		let perkinsSections = BrailleRegistry.filteredModeSections(for: .perkins)
		XCTAssertFalse(perkinsSections.contains(where: { $0.id == "typing" }))
		XCTAssertTrue(
			perkinsSections.first(where: { $0.id == "grade2" })?
				.options.contains(where: { $0.id == "grade2Suffixes" }) == true
		)
		XCTAssertTrue(
			perkinsSections.first(where: { $0.id == "grade2" })?
				.options.contains(where: { $0.id == "grade2Dot456Initials" }) == true
		)

		let brailleScreenSections = BrailleRegistry.filteredModeSections(for: .brailleText)
		XCTAssertFalse(brailleScreenSections.contains(where: { $0.id == "typing" }))
		XCTAssertTrue(
			brailleScreenSections.first(where: { $0.id == "grade2" })?
				.options.contains(where: { $0.id == "grade2Suffixes" }) == false
		)
	}

	func testLegacyModeMigration() {
		XCTAssertEqual(
			BrailleRegistry.sanitizedModeId("holyMoleyWordWar", for: .qwerty),
			WordyMoleMayhemCatalog.modeId
		)
	}

	func testRoundResultTerminologyMatchesMode() {
		let standard = makeResult(modeId: "grade1Letters", isWordMode: false)
		XCTAssertEqual(standard.completedTargetLabel, "Hits")
		XCTAssertNil(standard.wordInputLabel)
		XCTAssertEqual(standard.trainingCompletedLabel, "Training moles completed")
		XCTAssertEqual(standard.reconTargetNoun, "moles")

		let battle = makeResult(modeId: "grade1MoleBlitz", isWordMode: true)
		XCTAssertEqual(battle.completedTargetLabel, "Words completed")
		XCTAssertEqual(battle.wordInputLabel, "Letters whacked")
		XCTAssertEqual(battle.trainingCompletedLabel, "Training words completed")
		XCTAssertEqual(battle.reconTargetNoun, "words")

		let mayhem = makeResult(modeId: WordyMoleMayhemCatalog.modeId, isWordMode: true)
		XCTAssertEqual(mayhem.completedTargetLabel, "Words completed")
		XCTAssertEqual(mayhem.wordInputLabel, "Letters typed")
		XCTAssertEqual(mayhem.trainingCompletedLabel, "Training words completed")
		XCTAssertEqual(mayhem.reconTargetNoun, "words")
	}

	private func contents(of url: URL) throws -> String {
		try String(contentsOf: url, encoding: .utf8)
	}

	private func wordSet(at url: URL, includesComments: Bool = false) throws -> Set<String> {
		Set(
			try contents(of: url)
				.components(separatedBy: .newlines)
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
				.filter { !$0.isEmpty && (includesComments || !$0.hasPrefix("#")) }
		)
	}

	private func makeResult(modeId: String, isWordMode: Bool) -> RoundResult {
		RoundResult(
			modeId: modeId,
			inputMode: .qwerty,
			durationSeconds: 30,
			isTraining: false,
			trainingMolesCompleted: 0,
			isBlitzMode: isWordMode,
			lettersWhacked: 0,
			score: 0,
			hits: 0,
			misses: 0,
			escapes: 0,
			bestStreak: 0,
			streakBonusCount: 0,
			canceled: false,
			moleReconItems: [],
			grudgeMatchItems: [],
			usesAllShownMolesForRecon: false,
			baseTickets: 0,
			streakBonusTickets: 0,
			speedBonusTickets: 0
		)
	}
}

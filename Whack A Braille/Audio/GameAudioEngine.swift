import AVFoundation

final class GameAudioEngine {

	static let shared = GameAudioEngine()

	private let session = AVAudioSession.sharedInstance()

	private var timerMusicEnabled = true
	private var audioMode = "original"
	private var activePlayers: [AVAudioPlayer] = []

	private init() {}

	func prewarm() {
		configureAudioSession()
	}

	func configure(mode: String, timerMusicEnabled: Bool) {
		self.audioMode = mode == "silly" ? "silly" : "original"
		self.timerMusicEnabled = timerMusicEnabled
		configureAudioSession()
	}

	func playOpeningCue(playEverythingIntro: Bool) {
		configureAudioSession()

		if audioMode == "silly" {
			if playEverythingIntro {
				playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.7)
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
					self.playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.7)
				}
			} else {
				playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.6)
			}
		}
	}

	func startRoundAudio(progressProvider: @escaping () -> Double, timerMusicEnabled: Bool) {
		self.timerMusicEnabled = timerMusicEnabled
		_ = progressProvider
	}

	func stopRound() {
		stopAllPlayers()
	}

	func playHit(scoreBeforeHit: Int, lane: Int) {
		_ = lane

		if audioMode == "silly" {
			playBundledSound(named: "ChanceyBonk_6", fileExtension: "m4a", volume: 0.85)

			if scoreBeforeHit < 50, scoreBeforeHit + 10 >= 50 {
				playBundledSound(named: "50pts_2", fileExtension: "m4a", volume: 0.8)
			}
		}
	}

	func playMiss(lane: Int) {
		_ = lane
	}

	func playMolePop(lane: Int) {
		_ = lane
	}

	func playRetreat(lane: Int) {
		_ = lane
	}

	private func configureAudioSession() {
		do {
			try session.setCategory(.playback, mode: .default, options: [.duckOthers])
			try session.setActive(true)
		} catch {
			// Keep gameplay running even if the audio session update fails.
		}
	}

	private func playBundledSound(named name: String, fileExtension: String, volume: Float) {
		guard let url = bundledAudioURL(named: name, fileExtension: fileExtension) else { return }

		do {
			let player = try AVAudioPlayer(contentsOf: url)
			player.volume = volume
			player.prepareToPlay()
			activePlayers.append(player)
			player.play()
			purgeFinishedPlayers()
		} catch {
			// Keep gameplay running even if a bundled sound cannot be played.
		}
	}

	private func bundledAudioURL(named name: String, fileExtension: String) -> URL? {
		let possibleURLs: [URL?] = [
			Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources/Audio"),
			Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Audio"),
			Bundle.main.url(forResource: name, withExtension: fileExtension)
		]

		return possibleURLs.compactMap { $0 }.first
	}

	private func purgeFinishedPlayers() {
		activePlayers.removeAll { !$0.isPlaying }
	}

	private func stopAllPlayers() {
		for player in activePlayers {
			player.stop()
		}
		activePlayers.removeAll()
	}
}

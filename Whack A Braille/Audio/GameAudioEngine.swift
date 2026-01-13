import AVFoundation

final class GameAudioEngine {

	static let shared = GameAudioEngine()

	private let engine = AVAudioEngine()

	private let hitNode = AVAudioPlayerNode()
	private let missNode = AVAudioPlayerNode()
	private let popNode = AVAudioPlayerNode()
	private let retreatNode = AVAudioPlayerNode()

	private var hitBuffer: AVAudioPCMBuffer?
	private var missBuffer: AVAudioPCMBuffer?
	private var popBuffer: AVAudioPCMBuffer?
	private var retreatBuffer: AVAudioPCMBuffer?

	private init() {
		setupEngine()
	}

	private func setupEngine() {
		engine.attach(hitNode)
		engine.attach(missNode)
		engine.attach(popNode)
		engine.attach(retreatNode)

		let format = engine.mainMixerNode.outputFormat(forBus: 0)

		engine.connect(hitNode, to: engine.mainMixerNode, format: format)
		engine.connect(missNode, to: engine.mainMixerNode, format: format)
		engine.connect(popNode, to: engine.mainMixerNode, format: format)
		engine.connect(retreatNode, to: engine.mainMixerNode, format: format)

		do {
			try engine.start()
		} catch {
			fatalError("Failed to start audio engine: \(error)")
		}
	}

	// MARK: - Public API (called from GameLoop later)

	func playHit() {
		play(buffer: hitBuffer, on: hitNode)
	}

	func playMiss() {
		play(buffer: missBuffer, on: missNode)
	}

	func playPop() {
		play(buffer: popBuffer, on: popNode)
	}

	func playRetreat() {
		play(buffer: retreatBuffer, on: retreatNode)
	}

	// MARK: - Internals

	private func play(buffer: AVAudioPCMBuffer?, on node: AVAudioPlayerNode) {
		guard let buffer else { return }

		if !node.isPlaying {
			node.play()
		}

		node.scheduleBuffer(buffer, at: nil, options: .interrupts)
	}
}

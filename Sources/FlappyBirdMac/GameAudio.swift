import AVFoundation
import Foundation

@MainActor
final class GameAudio {
    private let flapPlayer: AVAudioPlayer?
    private let pointPlayer: AVAudioPlayer?
    private let hitPlayer: AVAudioPlayer?

    private(set) var muted = false
    var isHitPlaying: Bool { hitPlayer?.isPlaying ?? false }

    init() {
        flapPlayer = Self.loadPlayer(named: "flap")
        pointPlayer = Self.loadPlayer(named: "point")
        hitPlayer = Self.loadPlayer(named: "hit")
    }

    func playFlap() {
        play(flapPlayer)
    }

    func playPoint() {
        play(pointPlayer)
    }

    func playHit() {
        play(hitPlayer)
    }

    func toggleMute() {
        muted.toggle()
        if muted {
            stop(flapPlayer)
            stop(pointPlayer)
            stop(hitPlayer)
        }
    }

    private func play(_ player: AVAudioPlayer?) {
        guard !muted, let player else { return }
        player.currentTime = 0
        player.play()
    }

    private func stop(_ player: AVAudioPlayer?) {
        guard let player, player.isPlaying else { return }
        player.stop()
        player.currentTime = 0
    }

    private static func loadPlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "wav", subdirectory: "Assets") else {
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            // Audio failures must not interrupt play or scoring.
            return nil
        }
    }
}

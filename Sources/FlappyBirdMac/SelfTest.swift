import AppKit
import CoreGraphics
import Foundation

@MainActor
enum SelfTest {
    static func run() -> Int32 {
        do {
            try testGameState()
            try testHighScoreStore()
            try testRendererAndAssets()
            print("All FlappyBirdMac verification checks passed.")
            return 0
        } catch {
            fputs("Verification failed: \(error)\n", stderr)
            return 1
        }
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw NSError(domain: "FlappyBirdMacVerify", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static func testGameState() throws {
        let state = GameState()
        try check(state.score == 0, "Initial score must be 0")
        try check(!state.isGameOver, "Initial game must not be over")
        try check(!state.isBirdWingRaised, "Initial wing must not be raised")
        try check(state.obstacles.count == 2, "Must have 2 obstacle pairs")
        try check(state.birdX == (GameState.width - GameState.birdSize) / 2, "Bird must start centered on ready screen")

        let startY = state.birdY
        state.flap()
        try check(state.isBirdWingRaised, "Flap must raise bird wing")
        state.step()
        try check(state.birdY < startY, "Flap + step must move bird upward")
        try check(state.distanceTraveled == 4, "Each step must advance distance by 4")

        for _ in 0..<200 {
            if state.isGameOver { break }
            state.step()
        }
        try check(state.isGameOver, "Falling without flapping must hit ground and end game")
        try check(state.birdY + Double(GameState.birdSize) >= Double(GameState.groundY), "Bird bottom must reach groundY")
    }

    private static func testHighScoreStore() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = HighScoreStore(fileURL: tempDir.appendingPathComponent("high-score.txt"))
        let initial = store.tryLoad()
        try check(initial.success && initial.score == 0, "Missing high score file should load 0")

        let save1 = store.trySave(7)
        try check(save1.success && save1.savedScore == 7, "Saving 7 should succeed")

        let save2 = store.trySave(3)
        try check(save2.success && save2.savedScore == 7, "Saving lower score 3 should preserve 7")

        let reloaded = store.tryLoad()
        try check(reloaded.success && reloaded.score == 7, "Reloading should return 7")
    }

    private static func testRendererAndAssets() throws {
        try check(PixelAssets.loadAppIcon() != nil, "App icon should load from Assets/app.ico")

        let renderer = ArcadeRenderer()
        let audio = GameAudio()
        _ = audio.muted

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: GameState.width,
            height: GameState.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "FlappyBirdMacVerify", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create offscreen CGContext"])
        }
        context.translateBy(x: 0, y: CGFloat(GameState.height))
        context.scaleBy(x: 1, y: -1)

        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = nsContext
        defer { NSGraphicsContext.current = previous }

        let state = GameState()
        let bounds = CGRect(x: 0, y: 0, width: GameState.width, height: GameState.height)
        renderer.draw(context, bounds: bounds, game: state, running: false, paused: false, bestScore: 12, scoreMessage: nil)
        renderer.draw(context, bounds: bounds, game: state, running: true, paused: true, bestScore: 12, scoreMessage: nil)

        try check(context.makeImage() != nil, "Offscreen render must produce an image")
    }
}

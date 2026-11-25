import AppKit
import Foundation

@MainActor
final class GameView: NSView {
    private static let retryInputDelaySeconds: TimeInterval = 0.300
    private static let pauseButtonBounds = CGRect(x: 16, y: 16, width: 44, height: 44)
    private static let resumeButtonBounds = CGRect(x: 138, y: 280, width: 204, height: 42)
    private static let restartButtonBounds = CGRect(x: 138, y: 330, width: 204, height: 42)
    private static let soundButtonBounds = CGRect(x: 138, y: 380, width: 204, height: 42)

    private let game = GameState()
    private let renderer = ArcadeRenderer()
    private let audio = GameAudio()
    private let highScoreStore: HighScoreStore

    private var gameTimer: Timer?
    private var paused = false
    private var retryAllowedAt: Date = .distantPast
    private var bestScore = 0
    private var scoreMessage: String?

    private var pauseButton: ArcadeButton!
    private var resumeButton: ArcadeButton!
    private var restartButton: ArcadeButton!
    private var soundButton: ArcadeButton!
    private var retryButton: ArcadeButton!
    private var buttons: [ArcadeButton] = []

    private var pressedButton: ArcadeButton?
    private var trackingAreaRef: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(highScoreStore: HighScoreStore = HighScoreStore(fileURL: HighScoreStore.defaultURL())) {
        self.highScoreStore = highScoreStore
        super.init(frame: NSRect(x: 0, y: 0, width: 576, height: 768))

        let loaded = highScoreStore.tryLoad()
        if loaded.success {
            bestScore = loaded.score
        } else {
            scoreMessage = "Best score unavailable."
        }

        pauseButton = ArcadeButton(bounds: Self.pauseButtonBounds) { [weak self] in
            self?.togglePause()
        }
        resumeButton = ArcadeButton(bounds: Self.resumeButtonBounds, text: "Resume") { [weak self] in
            self?.togglePause()
        }
        restartButton = ArcadeButton(bounds: Self.restartButtonBounds, text: "New game", creamFace: true) { [weak self] in
            self?.resetGame()
        }
        soundButton = ArcadeButton(bounds: Self.soundButtonBounds, text: "Sound: On", creamFace: true, showsSpeaker: true) { [weak self] in
            guard let self else { return }
            self.audio.toggleMute()
            self.soundButton.setSpeakerMuted(self.audio.muted)
            self.needsDisplay = true
        }
        retryButton = ArcadeButton(bounds: ResultScreen.retryBounds, text: "Play again") { [weak self] in
            self?.flapOrRestart()
        }

        buttons = [pauseButton, resumeButton, restartButton, soundButton, retryButton]
        updateGameControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func keyDown(with event: NSEvent) {
        if event.isARepeat {
            return
        }

        switch event.keyCode {
        case 53: // Escape
            togglePause()
        case 49: // Space
            flapOrRestart()
        default:
            super.keyDown(with: event)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(for: event)
    }

    override func mouseExited(with event: NSEvent) {
        var changed = false
        for button in buttons where button.hovered {
            button.hovered = false
            changed = true
        }
        if changed {
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let gamePoint = toGameCoordinates(convert(event.locationInWindow, from: nil))

        if let hit = button(at: gamePoint) {
            pressedButton = hit
            hit.pressed = true
            hit.hovered = true
            needsDisplay = true
            return
        }

        if let gamePoint, CGRect(x: 0, y: 0, width: GameState.width, height: GameState.height).contains(gamePoint) {
            flapOrRestart()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pressedButton else { return }
        let gamePoint = toGameCoordinates(convert(event.locationInWindow, from: nil))
        let inside = gamePoint.map { pressedButton.bounds.contains($0) } ?? false
        if pressedButton.hovered != inside {
            pressedButton.hovered = inside
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let activeButton = pressedButton else {
            super.mouseUp(with: event)
            return
        }

        let gamePoint = toGameCoordinates(convert(event.locationInWindow, from: nil))
        let inside = gamePoint.map { activeButton.bounds.contains($0) } ?? false
        activeButton.pressed = false
        pressedButton = nil
        updateHover(for: event)
        needsDisplay = true

        if inside && activeButton.visible {
            activeButton.onClick()
        }
    }

    private func updateHover(for event: NSEvent) {
        let gamePoint = toGameCoordinates(convert(event.locationInWindow, from: nil))
        var changed = false
        for button in buttons {
            let shouldHover = button.visible && (gamePoint.map { button.bounds.contains($0) } ?? false)
            if button.hovered != shouldHover {
                button.hovered = shouldHover
                changed = true
            }
        }
        if changed {
            needsDisplay = true
        }
    }

    private func button(at gamePoint: CGPoint?) -> ArcadeButton? {
        guard let gamePoint else { return nil }
        return buttons.reversed().first { $0.visible && $0.bounds.contains(gamePoint) }
    }

    private var isRunning: Bool {
        gameTimer != nil
    }

    private func startTimer() {
        guard gameTimer == nil else { return }
        let timer = Timer(timeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceGame()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        gameTimer = timer
    }

    private func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    private func togglePause() {
        if !paused && !isRunning {
            return
        }

        paused.toggle()
        if paused {
            stopTimer()
        } else {
            startTimer()
        }
        updateGameControls()
    }

    private func updateGameControls() {
        pauseButton.showingPlayIcon = paused
        pauseButton.visible = paused || isRunning
        resumeButton.visible = paused
        restartButton.visible = paused
        soundButton.visible = paused
        retryButton.visible = game.isGameOver
        needsDisplay = true
    }

    private func flapOrRestart() {
        if paused {
            return
        }

        if game.isGameOver {
            if Date() < retryAllowedAt || audio.isHitPlaying {
                return
            }

            game.reset(fromReadyScreen: false)
        }

        game.flap()
        audio.playFlap()
        startTimer()
        updateGameControls()
    }

    private func advanceGame() {
        if paused {
            return
        }

        let previousScore = game.score
        game.step()
        if game.isGameOver {
            stopTimer()
            retryAllowedAt = Date().addingTimeInterval(Self.retryInputDelaySeconds)
            audio.playHit()
            saveHighScore()
            updateGameControls()
            return
        }

        if game.score > previousScore {
            audio.playPoint()
        }

        needsDisplay = true
    }

    private func saveHighScore() {
        if game.score <= bestScore {
            return
        }

        bestScore = game.score
        let result = highScoreStore.trySave(bestScore)
        if result.success {
            bestScore = result.savedScore
            scoreMessage = nil
        } else {
            scoreMessage = "Best score not saved."
        }
    }

    private func resetGame() {
        stopTimer()
        paused = false
        game.reset()
        updateGameControls()
    }

    private func gameViewport() -> CGRect {
        let scale = min(bounds.width / CGFloat(GameState.width), bounds.height / CGFloat(GameState.height))
        let width = CGFloat(GameState.width) * scale
        let height = CGFloat(GameState.height) * scale
        return CGRect(
            x: (bounds.width - width) / 2,
            y: (bounds.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func toGameCoordinates(_ viewPoint: CGPoint) -> CGPoint? {
        let viewport = gameViewport()
        guard viewport.width > 0, viewport.contains(viewPoint) else {
            return nil
        }
        let scale = viewport.width / CGFloat(GameState.width)
        return CGPoint(
            x: (viewPoint.x - viewport.minX) / scale,
            y: (viewPoint.y - viewport.minY) / scale
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(ArcadeRenderer.ink.cgColor)
        context.fill(bounds)

        let viewport = gameViewport()
        guard viewport.width > 0 else { return }

        let scale = viewport.width / CGFloat(GameState.width)
        context.saveGState()
        context.clip(to: viewport)
        context.translateBy(x: viewport.minX, y: viewport.minY)
        context.scaleBy(x: scale, y: scale)

        let gameBounds = CGRect(x: 0, y: 0, width: GameState.width, height: GameState.height)
        renderer.draw(
            context,
            bounds: gameBounds,
            game: game,
            running: isRunning,
            paused: paused,
            bestScore: bestScore,
            scoreMessage: scoreMessage
        )

        for button in buttons {
            button.draw(context)
        }

        context.restoreGState()
    }
}

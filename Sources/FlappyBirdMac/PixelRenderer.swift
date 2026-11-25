import AppKit
import CoreGraphics
import Foundation

extension NSColor {
    convenience init(r: Int, g: Int, b: Int, a: Int = 255) {
        self.init(
            srgbRed: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}

@MainActor
enum PixelAssets {
    static func load(_ name: String) -> CGImage {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Assets"),
              let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            fatalError("Missing embedded sprite: Assets/\(name).png")
        }
        return cgImage
    }

    static func loadAppIcon() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "app", withExtension: "ico", subdirectory: "Assets") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    static func draw(_ context: CGContext, sprite: CGImage, in destination: CGRect) {
        context.saveGState()
        context.translateBy(x: destination.minX, y: destination.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(sprite, in: CGRect(x: 0, y: 0, width: destination.width, height: destination.height))
        context.restoreGState()
    }
}

@MainActor
enum PixelHeading {
    // Each bit represents one pixel in a five-column row.
    private static let glyphs: [Character: [UInt8]] = [
        "A": [14, 17, 17, 31, 17, 17, 17],
        "D": [30, 17, 17, 17, 17, 17, 30],
        "E": [31, 16, 16, 30, 16, 16, 31],
        "G": [14, 17, 16, 23, 17, 17, 15],
        "P": [30, 17, 17, 30, 16, 16, 16],
        "S": [15, 16, 16, 14, 1, 1, 30],
        "Y": [17, 17, 10, 4, 4, 4, 4],
        "M": [17, 27, 31, 21, 17, 17, 17],
        "O": [14, 17, 17, 17, 17, 17, 14],
        "R": [30, 17, 17, 30, 20, 18, 17],
        "T": [31, 4, 4, 4, 4, 4, 4],
        "U": [17, 17, 17, 17, 17, 17, 14],
        "V": [17, 17, 17, 17, 17, 10, 4],
        " ": []
    ]

    static func draw(_ context: CGContext, text: String, top: Int) {
        let ink = ArcadeRenderer.ink.cgColor
        let cream = ArcadeRenderer.cream.cgColor
        let orange = NSColor(r: 255, g: 133, b: 25).cgColor

        context.saveGState()
        context.setShouldAntialias(false)
        drawLayer(context, text: text, top: top, color: cream, outline: 4)
        drawLayer(context, text: text, top: top, color: ink, outline: 2)
        drawLayer(context, text: text, top: top, color: orange, outline: 0)
        context.restoreGState()
    }

    private static func drawLayer(_ context: CGContext, text: String, top: Int, color: CGColor, outline: CGFloat) {
        let pixel = 5
        let advance = 6
        var left = (GameState.width - (text.count * advance - 1) * pixel) / 2
        context.setFillColor(color)

        for letter in text {
            let glyph = glyphs[letter] ?? []
            for (row, mask) in glyph.enumerated() {
                for column in 0..<5 {
                    if (mask & UInt8(16 >> column)) == 0 {
                        continue
                    }

                    let cell = CGRect(
                        x: left + column * pixel,
                        y: top + row * pixel,
                        width: pixel,
                        height: pixel
                    ).insetBy(dx: -outline, dy: -outline)
                    context.fill(cell)
                }
            }
            left += advance * pixel
        }
    }
}

@MainActor
enum ScoreDigits {
    private static let digitHeight = 24
    private static let defaultTop = 26
    private static let defaultScale: CGFloat = 1.5

    static func draw(_ context: CGContext, digits: String) {
        draw(context, digits: digits, centerX: CGFloat(GameState.width) / 2, top: defaultTop, scale: defaultScale, maxWidth: GameState.width)
    }

    static func draw(_ context: CGContext, digits: String, centerX: CGFloat, top: Int, scale: CGFloat, maxWidth: Int) {
        let totalDigitWidth = digits.reduce(0) { $0 + digitWidth($1) }
        let clampedScale = min(scale, CGFloat(maxWidth) / CGFloat(totalDigitWidth + 1))
        let width = CGFloat(totalDigitWidth) * clampedScale
        var x = 0

        context.saveGState()
        context.translateBy(x: centerX - width / 2, y: CGFloat(top))
        context.scaleBy(x: clampedScale, y: clampedScale)
        context.setShouldAntialias(false)

        let shadowColor = NSColor(r: 28, g: 63, b: 67).cgColor
        let blackColor = NSColor.black.cgColor

        for digit in digits {
            drawSilhouette(context, color: shadowColor, digit: digit, x: x + 1, y: 1)
            drawSilhouette(context, color: blackColor, digit: digit, x: x, y: 0)
            drawFace(context, digit: digit, x: x)
            x += digitWidth(digit)
        }

        context.restoreGState()
    }

    private static func digitWidth(_ digit: Character) -> Int {
        digit == "1" ? 11 : 16
    }

    private static func drawSilhouette(_ context: CGContext, color: CGColor, digit: Character, x: Int, y: Int) {
        context.setFillColor(color)
        switch digit {
        case "1":
            context.fill(CGRect(x: x, y: y, width: 11, height: 10))
            context.fill(CGRect(x: x + 2, y: y + 10, width: 9, height: digitHeight - 10))
        case "4":
            context.fill(CGRect(x: x, y: y, width: 16, height: 17))
            context.fill(CGRect(x: x + 8, y: y + 17, width: 8, height: digitHeight - 17))
        case "7":
            context.fill(CGRect(x: x, y: y, width: 16, height: 10))
            context.fill(CGRect(x: x + 8, y: y + 10, width: 8, height: digitHeight - 10))
        default:
            context.fill(CGRect(x: x, y: y, width: digitWidth(digit), height: digitHeight))
        }
    }

    private static func drawFace(_ context: CGContext, digit: Character, x: Int) {
        func white(_ left: Int, _ top: Int, _ width: Int, _ height: Int) {
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(x: x + left, y: top, width: width, height: height))
        }

        func black(_ left: Int, _ top: Int, _ width: Int, _ height: Int) {
            context.setFillColor(NSColor.black.cgColor)
            context.fill(CGRect(x: x + left, y: top, width: width, height: height))
        }

        switch digit {
        case "1":
            white(2, 2, 7, 6)
            white(4, 8, 5, 14)
            return
        case "4":
            white(2, 2, 12, 13)
            white(10, 15, 4, 7)
            black(6, 2, 2, 8)
            return
        case "7":
            white(2, 2, 12, 6)
            white(10, 8, 4, 14)
            return
        default:
            break
        }

        white(2, 2, 12, 20)
        switch digit {
        case "0":
            black(7, 7, 2, 10)
        case "2":
            black(2, 7, 8, 3)
            black(7, 14, 7, 2)
        case "3":
            black(2, 7, 8, 3)
            black(2, 14, 8, 3)
        case "5":
            black(7, 7, 7, 3)
            black(2, 14, 8, 3)
        case "6":
            black(7, 7, 7, 3)
            black(7, 15, 2, 2)
        case "8":
            black(7, 7, 2, 3)
            black(7, 14, 2, 3)
        case "9":
            black(7, 7, 2, 2)
            black(2, 15, 7, 2)
        default:
            break
        }
    }
}

@MainActor
enum ResultScreen {
    static let retryBounds = CGRect(x: 154, y: 325, width: 172, height: 46)
    private static let scorePanel = CGRect(x: 140, y: 235, width: 200, height: 72)

    static func draw(_ context: CGContext, score: Int, bestScore: Int, labelFont: NSFont, hintFont: NSFont) {
        PixelHeading.draw(context, text: "GAME OVER", top: 180)

        context.saveGState()
        context.setShouldAntialias(false)

        let shadow = scorePanel.offsetBy(dx: 4, dy: 5)
        context.setFillColor(ArcadeRenderer.ink.cgColor)
        context.fill(shadow)
        context.fill(scorePanel)
        context.setFillColor(ArcadeRenderer.cream.cgColor)
        context.fill(scorePanel.insetBy(dx: 2, dy: 2))
        context.restoreGState()

        drawScore(context, label: "SCORE", score: score, center: scorePanel.minX + scorePanel.width / 4, labelFont: labelFont)
        drawScore(context, label: "BEST", score: bestScore, center: scorePanel.maxX - scorePanel.width / 4, labelFont: labelFont)

        let hint = CGRect(x: retryBounds.minX, y: retryBounds.maxY + 4, width: retryBounds.width, height: 22)
        ArcadeRenderer.drawCentered(text: "Space", font: hintFont, color: ArcadeRenderer.ink, in: hint)
    }

    private static func drawScore(_ context: CGContext, label: String, score: Int, center: CGFloat, labelFont: NSFont) {
        let labelBounds = CGRect(x: center - 46, y: scorePanel.minY + 7, width: 92, height: 18)
        ArcadeRenderer.drawCentered(text: label, font: labelFont, color: ArcadeRenderer.ink, in: labelBounds)
        ScoreDigits.draw(context, digits: String(score), centerX: center, top: Int(scorePanel.minY) + 29, scale: 1.5, maxWidth: 88)
    }
}

@MainActor
final class ArcadeButton {
    private static let artWidth = 22
    private static let artHeight = 23

    let bounds: CGRect
    let creamFace: Bool
    let showsSpeaker: Bool
    var text: String
    var visible = false
    var hovered = false
    var pressed = false
    var showingPlayIcon = false
    var speakerMuted = false
    var onClick: () -> Void

    init(
        bounds: CGRect,
        text: String = "",
        creamFace: Bool = false,
        showsSpeaker: Bool = false,
        onClick: @escaping () -> Void
    ) {
        self.bounds = bounds
        self.text = text
        self.creamFace = creamFace
        self.showsSpeaker = showsSpeaker
        self.onClick = onClick
    }

    func setSpeakerMuted(_ muted: Bool) {
        speakerMuted = muted
        text = muted ? "Sound: Off" : "Sound: On"
    }

    func draw(_ context: CGContext) {
        guard visible else { return }

        let size = Int(min(bounds.width, bounds.height))
        guard size > 0 else { return }

        let iconOnly = text.isEmpty
        let width = iconOnly ? Self.artWidth : Int(bounds.width) * Self.artHeight / size

        context.saveGState()
        context.translateBy(x: bounds.minX, y: bounds.minY)
        if iconOnly {
            context.translateBy(x: (bounds.width - CGFloat(size)) / 2, y: (bounds.height - CGFloat(size)) / 2)
        }
        let scaleX = (iconOnly ? CGFloat(size) : bounds.width) / CGFloat(width)
        let scaleY = (iconOnly ? CGFloat(size) : bounds.height) / CGFloat(Self.artHeight)
        context.scaleBy(x: scaleX, y: scaleY)
        context.setShouldAntialias(false)
        drawFace(context, width: width)
        context.restoreGState()
    }

    private func drawSpeaker(_ context: CGContext, color: CGColor, x: Int, y: Int) {
        context.setFillColor(color)
        context.fill(CGRect(x: x, y: y + 2, width: 2, height: 4))
        context.fill(CGRect(x: x + 2, y: y + 1, width: 1, height: 6))
        context.fill(CGRect(x: x + 3, y: y, width: 1, height: 8))
        if speakerMuted {
            context.fill(CGRect(x: x + 5, y: y + 2, width: 1, height: 1))
            context.fill(CGRect(x: x + 6, y: y + 3, width: 1, height: 2))
            context.fill(CGRect(x: x + 5, y: y + 5, width: 1, height: 1))
            context.fill(CGRect(x: x + 7, y: y + 2, width: 1, height: 1))
            context.fill(CGRect(x: x + 7, y: y + 5, width: 1, height: 1))
        } else {
            context.fill(CGRect(x: x + 5, y: y + 2, width: 1, height: 4))
            context.fill(CGRect(x: x + 7, y: y + 1, width: 1, height: 6))
        }
    }

    private func drawFace(_ context: CGContext, width: Int) {
        let sunken = pressed && hovered
        let ink = NSColor(r: 52, g: 42, b: 31)
        let cream = NSColor(r: 255, g: 242, b: 209)
        let orange = sunken
            ? NSColor(r: 196, g: 81, b: 23)
            : (hovered ? NSColor(r: 243, g: 122, b: 37) : NSColor(r: 229, g: 106, b: 31))
        let highlight = NSColor(r: 251, g: 149, b: 55)
        let shadow = NSColor(r: 152, g: 67, b: 21)
        let neutralFace = sunken
            ? NSColor(r: 234, g: 214, b: 164)
            : (hovered ? NSColor(r: 255, g: 231, b: 165) : ArcadeRenderer.cream)
        let neutralShadow = NSColor(r: 165, g: 137, b: 85)

        context.setFillColor(ink.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: Self.artHeight))

        context.setFillColor(cream.cgColor)
        context.fill(CGRect(x: 1, y: 1, width: width - 2, height: 20))

        context.setFillColor((creamFace ? neutralShadow : shadow).cgColor)
        context.fill(CGRect(x: 3, y: 3, width: width - 6, height: 16))

        context.setFillColor((creamFace ? neutralFace : orange).cgColor)
        context.fill(CGRect(x: 3, y: sunken ? 5 : 3, width: width - 6, height: 14))

        context.setFillColor((creamFace ? cream : highlight).cgColor)
        context.fill(CGRect(x: 3, y: sunken ? 18 : 3, width: width - 6, height: 1))

        if !text.isEmpty {
            let font = NSFont.boldSystemFont(ofSize: 9)
            let top = sunken ? 5 : 3
            let textInset = showsSpeaker ? 13 : 3
            if showsSpeaker {
                let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
                let iconX = Int((CGFloat(width) - textWidth) / 2) - 10
                drawSpeaker(context, color: ink.cgColor, x: iconX, y: top + 4)
            }

            let textColor = creamFace ? ArcadeRenderer.ink : cream
            ArcadeRenderer.drawCentered(
                text: text,
                font: font,
                color: textColor,
                in: CGRect(x: textInset, y: top, width: width - textInset - 3, height: 14)
            )
            return
        }

        let iconTop = sunken ? 7 : 6
        context.setFillColor(cream.cgColor)
        if showingPlayIcon {
            for step in 0..<5 {
                context.fill(CGRect(x: 7 + step * 2, y: iconTop + step, width: 2, height: 9 - step * 2))
            }
        } else {
            context.fill(CGRect(x: 7, y: iconTop, width: 3, height: 9))
            context.fill(CGRect(x: 12, y: iconTop, width: 3, height: 9))
        }
    }
}

@MainActor
final class ArcadeRenderer {
    static let ink = NSColor(r: 23, g: 48, b: 65)
    static let cream = NSColor(r: 255, g: 248, b: 216)

    private static let groundPixelScale = 2
    private static let groundTileWidth = 28

    private let landscape: CGImage
    private let birdIdle: CGImage
    private let birdFlap: CGImage
    private let pipeBody: CGImage
    private let pipeCap: CGImage
    private let groundStrip: CGImage

    private let labelFont = NSFont.boldSystemFont(ofSize: 14)
    private let hintFont = NSFont.systemFont(ofSize: 14)

    init() {
        landscape = Self.createLandscape()
        birdIdle = PixelAssets.load("bird-idle")
        birdFlap = PixelAssets.load("bird-flap")
        pipeBody = PixelAssets.load("pipe-body")
        pipeCap = PixelAssets.load("pipe-cap")
        groundStrip = Self.createGroundStrip()
    }

    func draw(
        _ context: CGContext,
        bounds: CGRect,
        game: GameState,
        running: Bool,
        paused: Bool,
        bestScore: Int,
        scoreMessage: String?
    ) {
        let ready = !running && !paused && !game.isGameOver

        context.saveGState()
        context.interpolationQuality = .none
        context.setShouldAntialias(false)

        PixelAssets.draw(context, sprite: landscape, in: CGRect(x: 0, y: 0, width: bounds.width, height: CGFloat(GameState.groundY)))
        for obstacle in game.obstacles {
            drawPipePair(context, obstacle: obstacle)
        }

        drawBird(context, game: game)
        drawGround(context, bounds: bounds, distanceTraveled: game.distanceTraveled)
        context.restoreGState()

        if !game.isGameOver {
            ScoreDigits.draw(context, digits: String(game.score))
        }

        if paused {
            context.saveGState()
            context.setFillColor(NSColor(r: 23, g: 48, b: 65, a: 165).cgColor)
            context.fill(bounds)
            context.restoreGState()
            PixelHeading.draw(context, text: "PAUSED", top: 218)
        } else if game.isGameOver {
            ResultScreen.draw(context, score: game.score, bestScore: bestScore, labelFont: labelFont, hintFont: hintFont)
        } else if ready {
            drawStartMessage(context)
        }

        if let scoreMessage {
            let notice = CGRect(x: 323, y: 16, width: 141, height: 42)
            context.saveGState()
            context.setFillColor(Self.ink.cgColor)
            context.fill(notice)
            context.restoreGState()
            Self.drawCentered(text: scoreMessage, font: hintFont, color: Self.cream, in: notice)
        }
    }

    private func drawPipePair(_ context: CGContext, obstacle: GameState.Obstacle) {
        let x = obstacle.x
        let bodyX = x + GameState.pipeBodyInset
        let bodyWidth = GameState.pipeWidth - GameState.pipeBodyInset * 2
        let gapBottom = obstacle.gapTop + GameState.gapHeight
        let rimHeight = GameState.pipeRimHeight

        PixelAssets.draw(context, sprite: pipeBody, in: CGRect(x: bodyX, y: 0, width: bodyWidth, height: obstacle.gapTop))
        PixelAssets.draw(context, sprite: pipeBody, in: CGRect(x: bodyX, y: gapBottom, width: bodyWidth, height: GameState.groundY - gapBottom))
        PixelAssets.draw(context, sprite: pipeCap, in: CGRect(x: x, y: obstacle.gapTop - rimHeight, width: GameState.pipeWidth, height: rimHeight))
        PixelAssets.draw(context, sprite: pipeCap, in: CGRect(x: x, y: gapBottom, width: GameState.pipeWidth, height: rimHeight))
    }

    private func drawBird(_ context: CGContext, game: GameState) {
        let center = CGFloat(GameState.birdSize) / 2
        let pixelScale: CGFloat = 2.5
        let frame = game.isBirdWingRaised ? birdFlap : birdIdle
        let width = Int((CGFloat(frame.width) * pixelScale).rounded())
        let height = Int((CGFloat(frame.height) * pixelScale).rounded())
        let angleDegrees = min(max(game.birdVerticalSpeed * 3, -24), 30)
        let angleRadians = CGFloat(angleDegrees) * .pi / 180

        context.saveGState()
        context.translateBy(x: CGFloat(game.birdX) + center, y: CGFloat(game.birdY) + center)
        context.rotate(by: angleRadians)
        PixelAssets.draw(context, sprite: frame, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        context.restoreGState()
    }

    private func drawGround(_ context: CGContext, bounds: CGRect, distanceTraveled: Int64) {
        let top = CGFloat(GameState.groundY)
        let offset = Int(distanceTraveled % Int64(Self.groundTileWidth))
        // Scale a single strip so fractional window sizes cannot create gaps between tiles.
        PixelAssets.draw(
            context,
            sprite: groundStrip,
            in: CGRect(
                x: CGFloat(-offset),
                y: top,
                width: CGFloat(groundStrip.width * Self.groundPixelScale),
                height: bounds.height - top
            )
        )
    }

    private func drawStartMessage(_ context: CGContext) {
        PixelHeading.draw(context, text: "GET READY", top: 180)
        let hint = CGRect(x: 0, y: 352, width: GameState.width, height: 30)
        Self.drawCentered(text: "Click or press Space", font: labelFont, color: Self.ink, in: hint)
    }

    static func drawCentered(text: String, font: NSFont, color: NSColor, in bounds: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let size = attrString.size()
        let origin = CGPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2
        )
        attrString.draw(at: origin)
    }

    private static func createFlippedBitmapContext(width: Int, height: Int) -> CGContext {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("Could not allocate offscreen bitmap context")
        }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.setShouldAntialias(false)
        context.interpolationQuality = .none
        return context
    }

    private static func createLandscape() -> CGImage {
        let width = GameState.width
        let height = GameState.groundY
        let context = createFlippedBitmapContext(width: width, height: height)

        context.setFillColor(NSColor(r: 109, g: 198, b: 208).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let top = GameState.groundY - 122
        let cloudColor = NSColor(r: 236, g: 246, b: 223).cgColor
        let cloudShadeColor = NSColor(r: 215, g: 235, b: 218).cgColor
        let clouds: [(x: Int, y: Int, width: Int)] = [
            (-28, 12, 98), (64, 27, 102), (140, 3, 112),
            (251, 23, 90), (319, 0, 120), (419, 20, 106)
        ]
        for cloud in clouds {
            context.setFillColor(cloudColor)
            context.fill(CGRect(x: cloud.x, y: top + cloud.y + 18, width: cloud.width, height: 65))
            context.fill(CGRect(x: cloud.x + 12, y: top + cloud.y + 8, width: cloud.width - 24, height: 52))
            context.fill(CGRect(x: cloud.x + 28, y: top + cloud.y, width: cloud.width - 56, height: 35))
            context.setFillColor(cloudShadeColor)
            context.fill(CGRect(x: cloud.x, y: top + cloud.y + 58, width: cloud.width, height: 12))
        }

        let skylineBottom = GameState.groundY - 16
        let wallColor = NSColor(r: 159, g: 205, b: 196).cgColor
        let roofColor = NSColor(r: 192, g: 229, b: 213).cgColor
        let windowColor = NSColor(r: 220, g: 235, b: 211).cgColor
        let buildings: [(x: Int, width: Int, height: Int)] = [
            (0, 29, 49), (35, 31, 66), (72, 24, 42), (102, 43, 73),
            (153, 25, 53), (183, 24, 40), (213, 43, 70), (262, 30, 51),
            (297, 28, 66), (332, 37, 44), (375, 23, 61), (405, 36, 49), (446, 34, 64)
        ]
        for building in buildings {
            let buildingTop = skylineBottom - building.height
            context.setFillColor(wallColor)
            context.fill(CGRect(x: building.x, y: buildingTop, width: building.width, height: building.height))
            context.setFillColor(roofColor)
            context.fill(CGRect(x: building.x + 4, y: buildingTop + 4, width: building.width - 8, height: 4))
            context.setFillColor(windowColor)
            var row = buildingTop + 12
            while row < skylineBottom - 7 {
                var column = building.x + 6
                while column < building.x + building.width - 5 {
                    context.fill(CGRect(x: column, y: row, width: 4, height: 6))
                    column += 10
                }
                row += 12
            }
        }

        let shrubsColor = NSColor(r: 132, g: 190, b: 83).cgColor
        let leafLightColor = NSColor(r: 166, g: 208, b: 102).cgColor
        context.setFillColor(shrubsColor)
        context.fill(CGRect(x: 0, y: skylineBottom - 2, width: GameState.width, height: 18))
        var x = -12
        while x < GameState.width {
            context.setFillColor(shrubsColor)
            context.fill(CGRect(x: x, y: skylineBottom - 9, width: 32, height: 12))
            context.fill(CGRect(x: x + 6, y: skylineBottom - 15, width: 18, height: 8))
            context.setFillColor(leafLightColor)
            context.fill(CGRect(x: x + 5, y: skylineBottom - 8, width: 22, height: 3))
            x += 35
        }

        return context.makeImage()!
    }

    private static func createGroundStrip() -> CGImage {
        let tile = PixelAssets.load("ground-tile")
        let copies = (GameState.width + groundTileWidth - 1) / groundTileWidth + 1
        let stripWidth = tile.width * copies
        let stripHeight = tile.height
        let context = createFlippedBitmapContext(width: stripWidth, height: stripHeight)

        var x = 0
        while x < stripWidth {
            PixelAssets.draw(context, sprite: tile, in: CGRect(x: x, y: 0, width: tile.width, height: tile.height))
            x += tile.width
        }

        return context.makeImage()!
    }
}

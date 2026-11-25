import Foundation

public final class GameState {
    public static let width = 480
    public static let height = 640
    public static let groundY = 566
    public static let birdSize = 28
    public static let pipeWidth = 72
    public static let pipeRimHeight = 22
    public static let pipeBodyInset = 4
    public static let gapHeight = 120

    private static let minimumPipeSpacing = 255
    private static let maximumPipeSpacing = 295
    private static let minimumGapTop = 125
    private static let maximumGapTop = 305
    private static let scrollSpeed = 4
    private static let flightBirdX = 95
    private static let flightBirdY = 240.0
    private static let readyBirdX = (width - birdSize) / 2
    private static let readyBirdY = Double(320 - birdSize / 2)
    // The first pipe reaches the right edge one step before the bird settles into flight.
    private static let readyPipeX = width + (readyBirdX - flightBirdX - 1) / scrollSpeed * scrollSpeed
    private static let wingFlapDuration = 8

    public final class Obstacle {
        public var x: Int
        public var gapTop: Int
        public var scored: Bool

        public init(x: Int = 0, gapTop: Int = 0, scored: Bool = false) {
            self.x = x
            self.gapTop = gapTop
            self.scored = scored
        }
    }

    private var wingFlapTicks = 0

    public private(set) var birdX = 0
    public private(set) var birdY = 0.0
    public private(set) var birdVerticalSpeed = 0.0
    public var isBirdWingRaised: Bool { wingFlapTicks > 0 }
    public private(set) var score = 0
    public private(set) var distanceTraveled: Int64 = 0
    public private(set) var isGameOver = false
    public let obstacles: [Obstacle] = [Obstacle(), Obstacle()]

    public init() {
        reset()
    }

    public func reset(fromReadyScreen: Bool = true) {
        birdX = fromReadyScreen ? Self.readyBirdX : Self.flightBirdX
        birdY = fromReadyScreen ? Self.readyBirdY : Self.flightBirdY
        wingFlapTicks = 0
        birdVerticalSpeed = 0
        score = 0
        distanceTraveled = 0
        isGameOver = false

        let firstPipeX = fromReadyScreen ? Self.readyPipeX : Self.width + 35
        place(obstacles[0], x: firstPipeX, gapTop: Int.random(in: 145..<271))
        placeAfter(obstacles[1], previous: obstacles[0])
    }

    public func flap() {
        birdVerticalSpeed = -7.8
        wingFlapTicks = Self.wingFlapDuration
    }

    public func step() {
        if isGameOver {
            return
        }

        if wingFlapTicks > 0 {
            wingFlapTicks -= 1
        }

        birdVerticalSpeed = min(birdVerticalSpeed + 0.42, 10)
        birdY = max(0, birdY + birdVerticalSpeed)
        if birdY == 0 {
            birdVerticalSpeed = 0
        }

        birdX = max(Self.flightBirdX, birdX - Self.scrollSpeed)
        distanceTraveled += Int64(Self.scrollSpeed)

        for obstacle in obstacles {
            obstacle.x -= Self.scrollSpeed
        }

        isGameOver = birdY + Double(Self.birdSize) >= Double(Self.groundY) || obstacles.contains(where: hitsBird)
        if isGameOver {
            return
        }

        for obstacle in obstacles {
            if !obstacle.scored && obstacle.x + Self.pipeWidth <= birdX {
                obstacle.scored = true
                score += 1
            }

            if obstacle.x + Self.pipeWidth <= 0 {
                if let last = obstacles.max(by: { $0.x < $1.x }) {
                    placeAfter(obstacle, previous: last)
                }
            }
        }
    }

    private func hitsBird(_ obstacle: Obstacle) -> Bool {
        let right = obstacle.x + Self.pipeWidth
        if birdX >= right || birdX + Self.birdSize <= obstacle.x {
            return false
        }

        let birdBottom = birdY + Double(Self.birdSize)
        let gapBottom = obstacle.gapTop + Self.gapHeight
        let overlapsBody = birdX < right - Self.pipeBodyInset && birdX + Self.birdSize > obstacle.x + Self.pipeBodyInset
        if overlapsBody {
            return birdY < Double(obstacle.gapTop) || birdBottom > Double(gapBottom)
        }

        return (birdY < Double(obstacle.gapTop) && birdBottom > Double(obstacle.gapTop - Self.pipeRimHeight))
            || (birdY < Double(gapBottom + Self.pipeRimHeight) && birdBottom > Double(gapBottom))
    }

    private func placeAfter(_ obstacle: Obstacle, previous: Obstacle) {
        let spacing = Int.random(in: Self.minimumPipeSpacing...Self.maximumPipeSpacing)
        let gapTop = Int.random(in: Self.minimumGapTop...Self.maximumGapTop)
        place(obstacle, x: previous.x + spacing, gapTop: gapTop)
    }

    private func place(_ obstacle: Obstacle, x: Int, gapTop: Int) {
        obstacle.x = x
        obstacle.gapTop = gapTop
        obstacle.scored = false
    }
}

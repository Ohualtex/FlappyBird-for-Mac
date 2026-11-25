import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = PixelAssets.loadAppIcon() {
            NSApplication.shared.applicationIconImage = icon
        }

        setupMenuBar()

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 900)
        let preferredWidth: CGFloat = 576
        let maxScaleWidth = min(visibleFrame.width, visibleFrame.height * 3 / 4) - 40
        let startupWidth = max(CGFloat(GameState.width), min(preferredWidth, floor(maxScaleWidth / 3) * 3))
        let startupHeight = startupWidth * CGFloat(GameState.height) / CGFloat(GameState.width)

        let contentRect = NSRect(x: 0, y: 0, width: startupWidth, height: startupHeight)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Flappy Bird"
        window.backgroundColor = ArcadeRenderer.ink
        window.contentMinSize = NSSize(width: GameState.width, height: GameState.height)
        window.contentAspectRatio = NSSize(width: 3, height: 4)
        window.delegate = self

        let gameView = GameView()
        window.contentView = gameView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(gameView)
        self.window = window

        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit Flappy Bird",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        NSApplication.shared.mainMenu = mainMenu
    }
}

if CommandLine.arguments.contains("--verify") {
    exit(SelfTest.run())
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

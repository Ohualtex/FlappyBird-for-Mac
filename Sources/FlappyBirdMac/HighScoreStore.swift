import Foundation

public final class HighScoreStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport
            .appendingPathComponent("FlappyBird", isDirectory: true)
            .appendingPathComponent("high-score.txt", isDirectory: false)
    }

    public func tryLoad() -> (success: Bool, score: Int) {
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Int(text), value >= 0 {
                return (true, value)
            }
            return (false, 0)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && (error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError) {
            return (true, 0)
        } catch {
            return (false, 0)
        }
    }

    public func trySave(_ score: Int) -> (success: Bool, savedScore: Int) {
        let directory = fileURL.deletingLastPathComponent()
        let tempURL = directory.appendingPathComponent(fileURL.lastPathComponent + "." + UUID().uuidString + ".tmp")

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let loaded = tryLoad()
            if loaded.success && loaded.score >= score {
                return (true, loaded.score)
            }

            try String(score).write(to: tempURL, atomically: false, encoding: .utf8)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
            return (true, score)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, score)
        }
    }
}

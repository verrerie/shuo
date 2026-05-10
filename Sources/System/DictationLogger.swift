import Foundation

final class DictationLogger {
    private let directory: URL
    private let maxBytes: Int
    private let formatter: ISO8601DateFormatter
    private let queue = DispatchQueue(label: "app.shuo.logger")

    static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/Shuo", isDirectory: true)
    }

    init(directory: URL = DictationLogger.defaultDirectory(), maxBytes: Int = 5_000_000) {
        self.directory = directory
        self.maxBytes = maxBytes
        self.formatter = ISO8601DateFormatter()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private var fileURL: URL { directory.appendingPathComponent("shuo.log") }

    func log(durationMs: Int, bytesSent: Int, language: Language, result: String) {
        queue.async { [self] in
            let line = "\(formatter.string(from: Date())) | dur_ms=\(durationMs) bytes_sent=\(bytesSent) lang=\(language.rawValue) result=\(result)\n"
            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: fileURL)
            }
            truncateIfNeeded()
        }
    }

    /// Synchronously waits for any queued writes to complete. Tests use this to assert state.
    func waitForPendingWrites() {
        queue.sync { }
    }

    private func truncateIfNeeded() {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue,
              size > maxBytes else { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let tail = data.suffix(maxBytes)
        if let firstNL = tail.firstIndex(of: 0x0A) {
            let trimmed = tail.suffix(from: firstNL.advanced(by: 1))
            try? trimmed.write(to: fileURL)
        } else {
            try? tail.write(to: fileURL)
        }
    }
}

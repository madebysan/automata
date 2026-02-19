import Foundation

// Simple file-based activity log.
// Appends timestamped lines to ~/.mac-automata/logs/activity.log.
// Not for debugging — this is the user-facing run history.
enum Log {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    /// Log an informational message.
    static func info(_ message: String) {
        write("INFO", message)
    }

    /// Log a warning.
    static func warn(_ message: String) {
        write("WARN", message)
    }

    /// Log an error.
    static func error(_ message: String) {
        write("ERROR", message)
    }

    private static func write(_ level: String, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] \(message)\n"

        // Print to stdout for development
        print(line, terminator: "")

        // Append to log file
        let url = FileLocations.activityLog
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
}

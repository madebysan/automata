import Foundation

// Centralized path constants for all files Mac Automata creates.
// Everything lives in ~/.mac-automata/ except plists, which go
// in ~/Library/LaunchAgents/ where launchd expects them.
enum FileLocations {

    // MARK: - Base directories

    /// ~/.mac-automata/
    static let dataDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mac-automata")
    }()

    /// ~/.mac-automata/scripts/
    static let scriptsDir: URL = {
        dataDir.appendingPathComponent("scripts")
    }()

    /// ~/.mac-automata/logs/
    static let logsDir: URL = {
        dataDir.appendingPathComponent("logs")
    }()

    /// ~/Library/LaunchAgents/
    static let launchAgentsDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }()

    // MARK: - Specific files

    /// ~/.mac-automata/manifest.json — stores all automation configs
    static let manifestFile: URL = {
        dataDir.appendingPathComponent("manifest.json")
    }()

    /// ~/.mac-automata/logs/activity.log
    static let activityLog: URL = {
        logsDir.appendingPathComponent("activity.log")
    }()

    // MARK: - Dynamic paths

    /// Plist path for a given automation: ~/Library/LaunchAgents/com.macautomata.{type}-{id}.plist
    static func plistPath(type: String, id: String) -> URL {
        let label = plistLabel(type: type, id: id)
        return launchAgentsDir.appendingPathComponent("\(label).plist")
    }

    /// The launchd label for an automation: com.macautomata.{type}-{id}
    static func plistLabel(type: String, id: String) -> String {
        "com.macautomata.\(type)-\(id)"
    }

    /// Script path: ~/.mac-automata/scripts/{type}-{id}.sh (or .scpt for AppleScript)
    static func scriptPath(type: String, id: String, extension ext: String = "sh") -> URL {
        scriptsDir.appendingPathComponent("\(type)-\(id).\(ext)")
    }

    // MARK: - Setup

    /// Create all required directories if they don't exist yet.
    static func ensureDirectoriesExist() {
        let fm = FileManager.default
        for dir in [dataDir, scriptsDir, logsDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}

import Foundation

// Centralized path constants for all files Automata creates.
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

    // MARK: - Dynamic paths (automation-aware)

    /// Plist URL for an automation.
    static func plistURL(for automation: Automation) -> URL {
        launchAgentsDir.appendingPathComponent("\(automation.plistLabel).plist")
    }

    /// Script URL for an automation. Use suffix "-end" for time range revert scripts.
    static func scriptURL(for automation: Automation, suffix: String = "", extension ext: String) -> URL {
        scriptsDir.appendingPathComponent("\(automation.plistLabel)\(suffix).\(ext)")
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

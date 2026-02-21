import Foundation

// The "Do this" half of an automation.
// Each action knows how to describe itself, declare its config fields,
// generate the script content, and produce its sentence fragment.
enum ActionType: String, Codable, CaseIterable {
    case openApps = "open-apps"
    case quitApps = "quit-apps"
    case openFile = "open-file"
    case openURLs = "open-urls"
    case emptyTrash = "empty-trash"
    case cleanDownloads = "clean-downloads"
    case darkMode = "dark-mode"
    case setVolume = "set-volume"
    case moveFiles = "move-files"
    case showNotification = "show-notification"
    case keepAwake = "keep-awake"

    // MARK: - Display

    var name: String {
        switch self {
        case .openApps: return "Open app(s)"
        case .quitApps: return "Quit app(s)"
        case .openFile: return "Open a file"
        case .openURLs: return "Open URL(s)"
        case .emptyTrash: return "Empty the Trash"
        case .cleanDownloads: return "Clean old Downloads"
        case .darkMode: return "Toggle Dark Mode"
        case .setVolume: return "Set volume"
        case .moveFiles: return "Move files to..."
        case .showNotification: return "Show a notification"
        case .keepAwake: return "Keep Mac awake"
        }
    }

    var icon: String {
        switch self {
        case .openApps: return "square.grid.2x2"
        case .quitApps: return "xmark.square"
        case .openFile: return "doc.fill"
        case .openURLs: return "globe"
        case .emptyTrash: return "trash"
        case .cleanDownloads: return "folder.badge.minus"
        case .darkMode: return "moon.fill"
        case .setVolume: return "speaker.wave.2"
        case .moveFiles: return "folder.badge.plus"
        case .showNotification: return "bell"
        case .keepAwake: return "cup.and.heat.waves"
        }
    }

    // MARK: - Script

    /// Whether the script is AppleScript or a shell script.
    var isAppleScript: Bool {
        switch self {
        case .quitApps, .emptyTrash, .darkMode, .setVolume, .showNotification:
            return true
        case .openApps, .openFile, .openURLs, .cleanDownloads, .moveFiles, .keepAwake:
            return false
        }
    }

    var scriptExtension: String {
        isAppleScript ? "scpt" : "sh"
    }

    // MARK: - Config fields

    var fields: [BuilderField] {
        switch self {
        case .openApps:
            return [.appPicker(label: "Apps to open", multiple: true)]
        case .quitApps:
            return [.appPicker(label: "Apps to quit", multiple: true, allowAll: true)]
        case .openFile:
            return [.filePicker(label: "File to open")]
        case .openURLs:
            return [.urlList(label: "URLs (one per line)")]
        case .emptyTrash:
            return []
        case .cleanDownloads:
            return [.numberInput(label: "Delete files older than", placeholder: "30", unit: "days", key: "days")]
        case .darkMode:
            return [.dropdown(label: "Mode", key: "mode", options: ["dark", "light", "toggle"])]
        case .setVolume:
            return [.numberInput(label: "Volume level", placeholder: "50", unit: "% (0-100)", key: "volume")]
        case .moveFiles:
            return [.folderPicker(label: "Move files to", key: "destFolder")]
        case .showNotification:
            return [.textInput(label: "Message", placeholder: "Time to stretch!", key: "message")]
        case .keepAwake:
            return [.dropdown(label: "Stay awake for", key: "duration", options: ["30 min", "1 hour", "2 hours", "4 hours", "8 hours", "12 hours"])]
        }
    }

    // MARK: - Script generation

    func generateScript(config: [String: String], triggerConfig: [String: String]) -> String {
        switch self {
        case .openApps:
            let apps = parseApps(config["apps"] ?? "")
            var lines = ["#!/bin/bash", "# Open apps — Automata"]
            for app in apps { lines.append("open -a \"\(app)\"") }
            return lines.joined(separator: "\n")

        case .quitApps:
            if config["quitAll"] == "true" {
                return """
                tell application "System Events"
                    set allProcs to (every application process whose background only is false)
                    repeat with proc in allProcs
                        set procName to name of proc
                        if procName is not "MacAutomata" and procName is not "Finder" then
                            try
                                tell application procName to quit
                            end try
                        end if
                    end repeat
                end tell
                """
            }
            let apps = parseApps(config["apps"] ?? "")
            return apps.map { "tell application \"\($0)\" to quit" }.joined(separator: "\n")

        case .openFile:
            let path = config["filePath"] ?? ""
            return "#!/bin/bash\nopen \"\(path)\""

        case .openURLs:
            let urls = (config["urls"] ?? "").split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            var lines = ["#!/bin/bash", "# Open URLs — Automata"]
            for url in urls { lines.append("open \"\(url)\"") }
            return lines.joined(separator: "\n")

        case .emptyTrash:
            return "tell application \"Finder\"\n    empty the trash\nend tell"

        case .cleanDownloads:
            let days = config["days"] ?? "30"
            let logFile = FileLocations.logsDir.path + "/clean-downloads.log"
            return """
            #!/bin/bash
            LOG="\(logFile)"
            echo "--- Clean: $(date) ---" >> "$LOG"
            find "$HOME/Downloads" -maxdepth 1 -type f -mtime +\(days) -print0 | while IFS= read -r -d '' file; do
                echo "Deleting: $file" >> "$LOG"
                rm "$file"
            done
            """

        case .darkMode:
            let mode = config["mode"] ?? "toggle"
            switch mode {
            case "dark":
                return "tell application \"System Events\"\n    tell appearance preferences\n        set dark mode to true\n    end tell\nend tell"
            case "light":
                return "tell application \"System Events\"\n    tell appearance preferences\n        set dark mode to false\n    end tell\nend tell"
            default:
                return "tell application \"System Events\"\n    tell appearance preferences\n        set dark mode to not dark mode\n    end tell\nend tell"
            }

        case .setVolume:
            let vol = config["volume"] ?? "50"
            return "set volume output volume \(vol)"

        case .moveFiles:
            let dest = config["destFolder"] ?? ""
            // sourceFolder is set when trigger isn't fileAppears; watchFolder is the source for fileAppears
            let source = config["sourceFolder"] ?? triggerConfig["watchFolder"] ?? "$HOME/Downloads"
            let logFile = FileLocations.logsDir.path + "/move-files.log"
            return """
            #!/bin/bash
            SOURCE="\(source)"
            DEST="\(dest)"
            LOG="\(logFile)"
            echo "--- Move: $(date) ---" >> "$LOG"
            mkdir -p "$DEST"
            find "$SOURCE" -maxdepth 1 -type f -not -name '.*' -print0 | while IFS= read -r -d '' file; do
                echo "Moving: $(basename "$file")" >> "$LOG"
                mv "$file" "$DEST/"
            done
            """

        case .showNotification:
            let msg = (config["message"] ?? "Reminder").replacingOccurrences(of: "\"", with: "\\\"")
            return "display notification \"\(msg)\" with title \"Automata\""

        case .keepAwake:
            // In a time range, caffeinate runs indefinitely — the end script kills it.
            // For a one-shot trigger, use the configured duration.
            let isTimeRange = triggerConfig["startHour"] != nil
            if isTimeRange {
                return """
                #!/bin/bash
                # Keep Mac awake (time range) — Automata
                if [ -f /tmp/mac-automata-awake.pid ]; then
                    kill "$(cat /tmp/mac-automata-awake.pid)" 2>/dev/null || true
                fi
                caffeinate -dims &
                echo $! > /tmp/mac-automata-awake.pid
                """
            } else {
                let seconds = keepAwakeSeconds(config["duration"] ?? "1 hour")
                return """
                #!/bin/bash
                # Keep Mac awake — Automata
                if [ -f /tmp/mac-automata-awake.pid ]; then
                    kill "$(cat /tmp/mac-automata-awake.pid)" 2>/dev/null || true
                fi
                caffeinate -dims -t \(seconds) &
                echo $! > /tmp/mac-automata-awake.pid
                """
            }
        }
    }

    // MARK: - Sentence fragment

    /// The "do" part of the sentence: "open Xcode and Figma"
    func sentenceFragment(config: [String: String]) -> String {
        switch self {
        case .openApps:
            let apps = parseApps(config["apps"] ?? "")
            return "open \(apps.isEmpty ? "apps" : apps.joined(separator: " and "))"
        case .quitApps:
            if config["quitAll"] == "true" { return "quit all open apps" }
            let apps = parseApps(config["apps"] ?? "")
            return "quit \(apps.isEmpty ? "apps" : apps.joined(separator: " and "))"
        case .openFile:
            let name = ((config["filePath"] ?? "") as NSString).lastPathComponent
            return "open \(name.isEmpty ? "a file" : name)"
        case .openURLs:
            let count = (config["urls"] ?? "").split(separator: "\n").filter { !$0.isEmpty }.count
            return "open \(count == 1 ? "1 URL" : "\(count) URLs")"
        case .emptyTrash:
            return "empty the Trash"
        case .cleanDownloads:
            let days = config["days"] ?? "30"
            return "clean Downloads (files older than \(days) days)"
        case .darkMode:
            let mode = config["mode"] ?? "toggle"
            switch mode {
            case "dark": return "switch to Dark Mode"
            case "light": return "switch to Light Mode"
            default: return "toggle Dark Mode"
            }
        case .setVolume:
            return "set volume to \(config["volume"] ?? "50")%"
        case .moveFiles:
            let src = ((config["sourceFolder"] ?? "") as NSString).lastPathComponent
            let dest = ((config["destFolder"] ?? "") as NSString).lastPathComponent
            if !src.isEmpty {
                return "move files from \(src) to \(dest.isEmpty ? "a folder" : dest)"
            }
            return "move files to \(dest.isEmpty ? "a folder" : dest)"
        case .showNotification:
            let msg = config["message"] ?? "reminder"
            return "remind: \"\(msg)\""
        case .keepAwake:
            let duration = config["duration"] ?? "1 hour"
            return "keep Mac awake for \(duration)"
        }
    }

    // MARK: - Helpers

    private func keepAwakeSeconds(_ duration: String) -> Int {
        switch duration {
        case "30 min":   return 30 * 60
        case "1 hour":   return 60 * 60
        case "2 hours":  return 2 * 60 * 60
        case "4 hours":  return 4 * 60 * 60
        case "8 hours":  return 8 * 60 * 60
        case "12 hours": return 12 * 60 * 60
        default:         return 60 * 60
        }
    }

    // MARK: - Validation

    func validate(config: [String: String]) -> String? {
        switch self {
        case .openApps:
            guard let apps = config["apps"], !apps.isEmpty else {
                return "Please select at least one app"
            }
        case .quitApps:
            if config["quitAll"] != "true" {
                guard let apps = config["apps"], !apps.isEmpty else {
                    return "Please select at least one app, or check \"All open apps\""
                }
            }
        case .openFile:
            guard let path = config["filePath"], !path.isEmpty else {
                return "Please choose a file"
            }
        case .openURLs:
            guard let urls = config["urls"], !urls.isEmpty else {
                return "Please enter at least one URL"
            }
        case .cleanDownloads:
            guard let d = config["days"], let n = Int(d), n > 0 else {
                return "Please enter a number of days (must be > 0)"
            }
        case .setVolume:
            guard let v = config["volume"], let n = Int(v), n >= 0, n <= 100 else {
                return "Please enter a volume level between 0 and 100"
            }
        case .moveFiles:
            guard let dest = config["destFolder"], !dest.isEmpty else {
                return "Please choose a destination folder"
            }
        case .showNotification:
            guard let msg = config["message"], !msg.isEmpty else {
                return "Please enter a message"
            }
        case .darkMode, .emptyTrash, .keepAwake:
            break // No validation needed
        }
        return nil
    }

    // MARK: - Compatibility

    /// Triggers that make sense for this action.
    var compatibleTriggers: Set<TriggerType> {
        switch self {
        // System-level actions: no file relationship, but reversible → support timeRange
        case .darkMode, .setVolume, .keepAwake:
            return [.scheduledTime, .interval, .onLogin, .driveMount, .timeRange]
        // System-level and irreversible → no fileAppears, no timeRange
        case .emptyTrash, .cleanDownloads:
            return [.scheduledTime, .interval, .onLogin, .driveMount]
        // Reversible app actions → all triggers including timeRange
        case .openApps, .quitApps:
            return Set(TriggerType.allCases)
        // Fire-and-forget, no meaningful revert → all triggers except timeRange
        case .openFile, .openURLs, .moveFiles, .showNotification:
            return Set(TriggerType.allCases).subtracting([.timeRange])
        }
    }

    // MARK: - Time range revert

    /// True when this action can be used in a time range (has a meaningful revert).
    var supportsTimeRange: Bool {
        compatibleTriggers.contains(.timeRange)
    }

    /// Whether the revert script is AppleScript (vs shell).
    var isRevertAppleScript: Bool {
        switch self {
        case .darkMode, .setVolume: return true   // same as main script
        case .openApps: return true               // revert of "open" is "quit" (AppleScript)
        case .quitApps: return false              // revert of "quit" is "open -a" (shell)
        case .keepAwake: return false             // revert is a shell kill command
        default: return false
        }
    }

    /// The script that undoes the action at the end of a time range.
    func revertScript(config: [String: String]) -> String {
        switch self {
        case .darkMode:
            let mode = config["mode"] ?? "dark"
            // Revert to the opposite of what was applied
            let isDark = mode == "dark"
            return isDark
                ? "tell application \"System Events\"\n    tell appearance preferences\n        set dark mode to false\n    end tell\nend tell"
                : "tell application \"System Events\"\n    tell appearance preferences\n        set dark mode to true\n    end tell\nend tell"

        case .setVolume:
            let vol = config["revertVolume"] ?? "50"
            return "set volume output volume \(vol)"

        case .keepAwake:
            return """
            #!/bin/bash
            # End keep-awake time range — Automata
            if [ -f /tmp/mac-automata-awake.pid ]; then
                kill "$(cat /tmp/mac-automata-awake.pid)" 2>/dev/null || true
                rm -f /tmp/mac-automata-awake.pid
            fi
            """

        case .quitApps:
            // Revert of "quit apps" = reopen them
            let apps = parseApps(config["apps"] ?? "")
            var lines = ["#!/bin/bash", "# Reopen apps — Automata"]
            for app in apps { lines.append("open -a \"\(app)\"") }
            return lines.joined(separator: "\n")

        case .openApps:
            // Revert of "open apps" = quit them
            let apps = parseApps(config["apps"] ?? "")
            return apps.map { "tell application \"\($0)\" to quit" }.joined(separator: "\n")

        default:
            return ""
        }
    }

    private func parseApps(_ str: String) -> [String] {
        str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

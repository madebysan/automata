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
        }
    }

    // MARK: - Script

    /// Whether the script is AppleScript or a shell script.
    var isAppleScript: Bool {
        switch self {
        case .quitApps, .emptyTrash, .darkMode, .setVolume, .showNotification:
            return true
        case .openApps, .openFile, .openURLs, .cleanDownloads, .moveFiles:
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
            return [.appPicker(label: "Apps to quit", multiple: true)]
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
        }
    }

    // MARK: - Script generation

    func generateScript(config: [String: String], triggerConfig: [String: String]) -> String {
        switch self {
        case .openApps:
            let apps = parseApps(config["apps"] ?? "")
            var lines = ["#!/bin/bash", "# Open apps — Mac Automata"]
            for app in apps { lines.append("open -a \"\(app)\"") }
            return lines.joined(separator: "\n")

        case .quitApps:
            let apps = parseApps(config["apps"] ?? "")
            return apps.map { "tell application \"\($0)\" to quit" }.joined(separator: "\n")

        case .openFile:
            let path = config["filePath"] ?? ""
            return "#!/bin/bash\nopen \"\(path)\""

        case .openURLs:
            let urls = (config["urls"] ?? "").split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            var lines = ["#!/bin/bash", "# Open URLs — Mac Automata"]
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
            let source = triggerConfig["watchFolder"] ?? "$HOME/Downloads"
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
            return "display notification \"\(msg)\" with title \"Mac Automata\""
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
            let dest = ((config["destFolder"] ?? "") as NSString).lastPathComponent
            return "move files to \(dest.isEmpty ? "a folder" : dest)"
        case .showNotification:
            let msg = config["message"] ?? "reminder"
            return "remind: \"\(msg)\""
        }
    }

    // MARK: - Validation

    func validate(config: [String: String]) -> String? {
        switch self {
        case .openApps, .quitApps:
            guard let apps = config["apps"], !apps.isEmpty else {
                return "Please select at least one app"
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
        case .darkMode, .emptyTrash:
            break // No validation needed
        }
        return nil
    }

    private func parseApps(_ str: String) -> [String] {
        str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

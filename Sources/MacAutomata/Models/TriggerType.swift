import Foundation

// The "When" half of an automation.
// Each trigger knows how to describe itself, declare its config fields,
// generate the launchd plist trigger entries, and produce its sentence fragment.
enum TriggerType: String, Codable, CaseIterable {
    case scheduledTime = "scheduled-time"
    case interval = "interval"
    case onLogin = "on-login"
    case fileAppears = "file-appears"
    case driveMount = "drive-mount"

    // MARK: - Display

    var name: String {
        switch self {
        case .scheduledTime: return "At a specific time"
        case .interval: return "Every N minutes"
        case .onLogin: return "On login"
        case .fileAppears: return "When a file appears in..."
        case .driveMount: return "When a drive is mounted"
        }
    }

    var icon: String {
        switch self {
        case .scheduledTime: return "clock"
        case .interval: return "repeat"
        case .onLogin: return "power"
        case .fileAppears: return "eye"
        case .driveMount: return "externaldrive.connected.to.line.below"
        }
    }

    var description: String {
        switch self {
        case .scheduledTime: return "Pick a time and days of the week"
        case .interval: return "Repeats on a fixed cadence"
        case .onLogin: return "Runs once when you log in"
        case .fileAppears: return "Fires when a folder's contents change"
        case .driveMount: return "Fires when a USB drive or SD card is plugged in"
        }
    }

    // MARK: - Config fields

    /// The fields the user needs to fill in for this trigger.
    var fields: [BuilderField] {
        switch self {
        case .scheduledTime:
            return [.timePicker, .weekdayPicker]
        case .interval:
            return [.numberInput(label: "Repeat every", placeholder: "30", unit: "minutes", key: "interval")]
        case .onLogin:
            return [] // No config needed
        case .fileAppears:
            return [.folderPicker(label: "Watch this folder", key: "watchFolder")]
        case .driveMount:
            return [] // No config needed
        }
    }

    // MARK: - Plist trigger entries

    /// Generate the launchd plist keys for this trigger.
    func plistEntries(config: [String: String]) -> [String: Any] {
        switch self {
        case .scheduledTime:
            return ["StartCalendarInterval": buildCalendarInterval(config)]
        case .interval:
            let minutes = Int(config["interval"] ?? "30") ?? 30
            return ["StartInterval": minutes * 60]
        case .onLogin:
            return ["RunAtLoad": true]
        case .fileAppears:
            let path = config["watchFolder"] ?? ""
            return ["WatchPaths": [path]]
        case .driveMount:
            return ["StartOnMount": true]
        }
    }

    // MARK: - Sentence fragment

    /// The "when" part of the sentence: "Every weekday at 9:00 AM"
    func sentenceFragment(config: [String: String]) -> String {
        switch self {
        case .scheduledTime:
            let time = formatTime(config)
            let days = formatDays(config)
            return "\(days) at \(time)"
        case .interval:
            let min = config["interval"] ?? "30"
            return "Every \(min) min"
        case .onLogin:
            return "On login"
        case .fileAppears:
            let folder = (config["watchFolder"] as NSString?)?.lastPathComponent ?? "a folder"
            return "When files appear in \(folder)"
        case .driveMount:
            return "When a drive is mounted"
        }
    }

    // MARK: - Helpers

    private func formatTime(_ config: [String: String]) -> String {
        let hour = Int(config["hour"] ?? "9") ?? 9
        let minute = Int(config["minute"] ?? "0") ?? 0
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    private func formatDays(_ config: [String: String]) -> String {
        guard let daysStr = config["weekdays"], !daysStr.isEmpty else {
            return "Every day"
        }
        let days = daysStr.split(separator: ",").compactMap { Int($0) }.sorted()
        if days.count == 7 { return "Every day" }
        if Set(days) == Set([2, 3, 4, 5, 6]) { return "Every weekday" }
        if Set(days) == Set([1, 7]) { return "Every weekend" }

        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.compactMap { d -> String? in
            let i = d - 1
            return i >= 0 && i < names.count ? names[i] : nil
        }.joined(separator: ", ")
    }

    private func buildCalendarInterval(_ config: [String: String]) -> Any {
        let hour = Int(config["hour"] ?? "9") ?? 9
        let minute = Int(config["minute"] ?? "0") ?? 0
        if let daysStr = config["weekdays"], !daysStr.isEmpty {
            let days = daysStr.split(separator: ",").compactMap { Int($0) }
            if days.count == 7 || days.isEmpty {
                return ["Hour": hour, "Minute": minute] as [String: Int]
            }
            return days.map { ["Hour": hour, "Minute": minute, "Weekday": $0] as [String: Int] }
        }
        return ["Hour": hour, "Minute": minute] as [String: Int]
    }
}

import Foundation

// Every recipe type the app supports.
// Adding a new recipe = new enum case + new RecipeProvider file + register in RecipeRegistry.
enum RecipeType: String, Codable, CaseIterable {
    // Time-based (StartCalendarInterval)
    case openApps = "open-apps"
    case quitApps = "quit-apps"
    case darkMode = "dark-mode"
    case emptyTrash = "empty-trash"
    case openURLs = "open-urls"
    case cleanDownloads = "clean-downloads"
    case volume = "volume"
    case openFile = "open-file"
    // Event-based
    case watchAndMove = "watch-move"
    case onMount = "on-mount"
    case loginLaunch = "login-launch"
    case intervalNotify = "interval-notify"
}

// What kind of script a recipe generates.
enum ScriptKind {
    case appleScript  // .scpt file, run via osascript
    case shellScript  // .sh file, run via bash
}

// Describes what a recipe needs from the user.
// Each field becomes a UI control in the config view.
enum RecipeField {
    case appPicker(label: String, multiple: Bool)
    case timePicker(label: String)
    case weekdayPicker(label: String)
    case numberField(label: String, placeholder: String, unit: String)
    case urlList(label: String)
    case toggle(label: String, key: String)
    case dropdown(label: String, key: String, options: [String])
    case filePicker(label: String)
    case folderPicker(label: String, key: String)
    case textField(label: String, placeholder: String, key: String)
}

// The protocol every recipe conforms to.
protocol RecipeProvider {

    /// Unique type identifier.
    var type: RecipeType { get }

    /// Display name shown in the recipe picker.
    var name: String { get }

    /// SF Symbol name for the trigger/action icons.
    var triggerIcon: String { get }
    var actionIcon: String { get }

    /// Short description shown under the recipe name.
    var description: String { get }

    /// What kind of script this recipe generates.
    var scriptKind: ScriptKind { get }

    /// The fields the user needs to fill in.
    var fields: [RecipeField] { get }

    /// Validate user-provided config values. Returns nil if valid,
    /// or an error message if something is wrong.
    func validate(config: [String: String]) -> String?

    /// Generate the script content from the user's config.
    func generateScript(config: [String: String]) -> String

    /// Generate the plain-English sentence describing this automation.
    func sentence(config: [String: String]) -> String

    /// Return the plist trigger entries to merge into the launchd plist.
    /// Keys are launchd plist keys like "StartCalendarInterval", "WatchPaths",
    /// "RunAtLoad", "StartInterval", "StartOnMount".
    func plistTriggerEntries(config: [String: String]) -> [String: Any]
}

// Shared helpers for formatting time, days, and building launchd schedules.
extension RecipeProvider {

    /// Format hour/minute config into "9:00 AM" style string.
    func formatTime(_ config: [String: String]) -> String {
        let hour = Int(config["hour"] ?? "9") ?? 9
        let minute = Int(config["minute"] ?? "0") ?? 0
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    /// Format weekday config into "Every weekday" / "Every day" / etc.
    func formatDays(_ config: [String: String]) -> String {
        guard let daysStr = config["weekdays"], !daysStr.isEmpty else {
            return "Every day"
        }
        let days = daysStr.split(separator: ",").compactMap { Int($0) }.sorted()
        if days.count == 7 { return "Every day" }

        let weekdaySet: Set<Int> = [2, 3, 4, 5, 6]
        if Set(days) == weekdaySet { return "Every weekday" }

        let weekendSet: Set<Int> = [1, 7]
        if Set(days) == weekendSet { return "Every weekend" }

        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayNames = days.compactMap { d -> String? in
            let index = d - 1
            return index >= 0 && index < names.count ? names[index] : nil
        }
        return dayNames.joined(separator: ", ")
    }

    /// Build the StartCalendarInterval value from hour/minute/weekday config.
    func buildCalendarInterval(_ config: [String: String]) -> Any {
        let hour = Int(config["hour"] ?? "9") ?? 9
        let minute = Int(config["minute"] ?? "0") ?? 0

        if let daysStr = config["weekdays"], !daysStr.isEmpty {
            let days = daysStr.split(separator: ",").compactMap { Int($0) }
            if days.count == 7 || days.isEmpty {
                return ["Hour": hour, "Minute": minute] as [String: Int]
            }
            return days.map { day in
                ["Hour": hour, "Minute": minute, "Weekday": day] as [String: Int]
            }
        }

        return ["Hour": hour, "Minute": minute] as [String: Int]
    }

    /// Default trigger for time-based recipes — wraps buildCalendarInterval.
    func calendarTrigger(_ config: [String: String]) -> [String: Any] {
        return ["StartCalendarInterval": buildCalendarInterval(config)]
    }
}

// Central registry of all available recipes.
enum RecipeRegistry {

    static let all: [RecipeProvider] = [
        // Event-driven (new triggers)
        LoginLaunchRecipe(),
        WatchAndMoveRecipe(),
        OnMountRecipe(),
        IntervalNotifyRecipe(),
        // Time-based
        OpenAppsRecipe(),
        QuitAppsRecipe(),
        OpenFileRecipe(),
        OpenURLsRecipe(),
        DarkModeRecipe(),
        EmptyTrashRecipe(),
        CleanDownloadsRecipe(),
        VolumeRecipe(),
    ]

    static func provider(for type: RecipeType) -> RecipeProvider? {
        all.first { $0.type == type }
    }
}

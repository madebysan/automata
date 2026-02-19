import Foundation

// Every recipe type the app supports.
// Adding a new recipe = new enum case + new RecipeProvider file + register in RecipeRegistry.
enum RecipeType: String, Codable, CaseIterable {
    case openApps = "open-apps"
    case quitApps = "quit-apps"
    case darkMode = "dark-mode"
    case emptyTrash = "empty-trash"
    case openURLs = "open-urls"
    case cleanDownloads = "clean-downloads"
    case volume = "volume"
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
}

// The protocol every recipe conforms to.
// Knows how to describe itself, declare its fields, validate input,
// generate the script content, and specify the launchd schedule.
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
    /// Example: "Every weekday at 9:00 AM, open Xcode and Figma"
    func sentence(config: [String: String]) -> String

    /// Build the launchd schedule dictionary for the plist.
    /// Returns the value for the StartCalendarInterval key.
    func scheduleDict(config: [String: String]) -> Any
}

// Shared helpers for formatting time, days, and building launchd schedules.
// All recipes get these for free via protocol extension.
extension RecipeProvider {

    /// Format hour/minute config into "9:00 AM" style string.
    func formatTime(_ config: [String: String]) -> String {
        let hour = Int(config["hour"] ?? "9") ?? 9
        let minute = Int(config["minute"] ?? "0") ?? 0
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    /// Format weekday config into "Every weekday" / "Every day" / "Mon, Wed, Fri" style.
    /// Weekdays stored as comma-separated 1-7 (1=Sunday per launchd).
    func formatDays(_ config: [String: String]) -> String {
        guard let daysStr = config["weekdays"], !daysStr.isEmpty else {
            return "Every day"
        }
        let days = daysStr.split(separator: ",").compactMap { Int($0) }.sorted()
        if days.count == 7 { return "Every day" }

        let weekdaySet: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri in launchd numbering
        if Set(days) == weekdaySet { return "Every weekday" }

        let weekendSet: Set<Int> = [1, 7] // Sun, Sat
        if Set(days) == weekendSet { return "Every weekend" }

        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayNames = days.compactMap { d -> String? in
            let index = d - 1 // launchd 1-7 to 0-6
            return index >= 0 && index < names.count ? names[index] : nil
        }
        return dayNames.joined(separator: ", ")
    }

    /// Build the launchd StartCalendarInterval dictionary from config.
    /// If weekdays are specified, returns an array of dicts (one per day).
    /// Otherwise returns a single dict that fires every day.
    func buildSchedule(_ config: [String: String]) -> Any {
        let hour = Int(config["hour"] ?? "9") ?? 9
        let minute = Int(config["minute"] ?? "0") ?? 0

        if let daysStr = config["weekdays"], !daysStr.isEmpty {
            let days = daysStr.split(separator: ",").compactMap { Int($0) }
            if days.count == 7 || days.isEmpty {
                // Every day — no Weekday key needed
                return ["Hour": hour, "Minute": minute] as [String: Int]
            }
            // One dict per day
            return days.map { day in
                ["Hour": hour, "Minute": minute, "Weekday": day] as [String: Int]
            }
        }

        return ["Hour": hour, "Minute": minute] as [String: Int]
    }
}

// Central registry of all available recipes.
// The UI uses this to populate the recipe picker.
enum RecipeRegistry {

    /// All recipe providers, in display order.
    static let all: [RecipeProvider] = [
        EmptyTrashRecipe(),
        OpenAppsRecipe(),
        QuitAppsRecipe(),
        DarkModeRecipe(),
        OpenURLsRecipe(),
        CleanDownloadsRecipe(),
        VolumeRecipe(),
    ]

    /// Look up a recipe provider by type.
    static func provider(for type: RecipeType) -> RecipeProvider? {
        all.first { $0.type == type }
    }
}

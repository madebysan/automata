import Foundation

// Recipe: Toggle Dark Mode on a schedule.
// Uses AppleScript to tell System Events to change the appearance.
struct DarkModeRecipe: RecipeProvider {

    let type = RecipeType.darkMode
    let name = "Toggle Dark Mode"
    let triggerIcon = "clock"
    let actionIcon = "moon.fill"
    let description = "Switch to Dark or Light mode at a set time"
    let scriptKind = ScriptKind.appleScript

    let fields: [RecipeField] = [
        .dropdown(label: "Mode", key: "mode", options: ["dark", "light", "toggle"]),
        .timePicker(label: "Time"),
        .weekdayPicker(label: "Days"),
    ]

    func validate(config: [String: String]) -> String? {
        guard let mode = config["mode"], ["dark", "light", "toggle"].contains(mode) else {
            return "Please select a mode"
        }
        guard config["hour"] != nil, config["minute"] != nil else {
            return "Please set a time"
        }
        return nil
    }

    func generateScript(config: [String: String]) -> String {
        let mode = config["mode"] ?? "toggle"
        switch mode {
        case "dark":
            return """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to true
                end tell
            end tell
            """
        case "light":
            return """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to false
                end tell
            end tell
            """
        default: // toggle
            return """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to not dark mode
                end tell
            end tell
            """
        }
    }

    func sentence(config: [String: String]) -> String {
        let mode = config["mode"] ?? "toggle"
        let time = formatTime(config)
        let days = formatDays(config)
        let action: String
        switch mode {
        case "dark": action = "switch to Dark Mode"
        case "light": action = "switch to Light Mode"
        default: action = "toggle Dark Mode"
        }
        return "\(days) at \(time), \(action)"
    }

    func scheduleDict(config: [String: String]) -> Any {
        return buildSchedule(config)
    }
}

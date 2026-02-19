import Foundation

// Recipe: Quit one or more apps on a schedule.
struct QuitAppsRecipe: RecipeProvider {

    let type = RecipeType.quitApps
    let name = "Quit Apps"
    let triggerIcon = "clock"
    let actionIcon = "xmark.square"
    let description = "Close apps at a specific time"
    let scriptKind = ScriptKind.appleScript

    let fields: [RecipeField] = [
        .appPicker(label: "Apps to quit", multiple: true),
        .timePicker(label: "Time"),
        .weekdayPicker(label: "Days"),
    ]

    func validate(config: [String: String]) -> String? {
        guard let apps = config["apps"], !apps.isEmpty else {
            return "Please select at least one app"
        }
        guard config["hour"] != nil, config["minute"] != nil else {
            return "Please set a time"
        }
        return nil
    }

    func generateScript(config: [String: String]) -> String {
        let apps = (config["apps"] ?? "").split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        var lines = [String]()
        for app in apps {
            lines.append("""
            tell application "\(app)"
                quit
            end tell
            """)
        }
        return lines.joined(separator: "\n")
    }

    func sentence(config: [String: String]) -> String {
        let apps = (config["apps"] ?? "").split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        let time = formatTime(config)
        let days = formatDays(config)
        let appList = apps.isEmpty ? "apps" : apps.joined(separator: " and ")
        return "\(days) at \(time), quit \(appList)"
    }

    func plistTriggerEntries(config: [String: String]) -> [String: Any] {
        return calendarTrigger(config)
    }
}

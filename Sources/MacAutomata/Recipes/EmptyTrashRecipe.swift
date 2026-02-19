import Foundation

// Recipe: Empty the Trash on a schedule.
// The simplest recipe — one AppleScript command, schedule-only trigger.
struct EmptyTrashRecipe: RecipeProvider {

    let type = RecipeType.emptyTrash
    let name = "Empty Trash"
    let triggerIcon = "clock"
    let actionIcon = "trash"
    let description = "Empty the Trash on a recurring schedule"
    let scriptKind = ScriptKind.appleScript

    let fields: [RecipeField] = [
        .timePicker(label: "Time"),
        .weekdayPicker(label: "Days"),
    ]

    func validate(config: [String: String]) -> String? {
        guard config["hour"] != nil, config["minute"] != nil else {
            return "Please set a time"
        }
        return nil
    }

    func generateScript(config: [String: String]) -> String {
        // AppleScript to empty the Trash via Finder
        return """
        tell application "Finder"
            empty the trash
        end tell
        """
    }

    func sentence(config: [String: String]) -> String {
        let time = formatTime(config)
        let days = formatDays(config)
        return "\(days) at \(time), empty the Trash"
    }

    func scheduleDict(config: [String: String]) -> Any {
        return buildSchedule(config)
    }
}

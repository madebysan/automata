import Foundation

// Recipe: Show a notification on a repeating interval.
// Uses launchd StartInterval — fires every N seconds.
// Great for reminders: "Stand up every 30 min", "Drink water every hour".
struct IntervalNotifyRecipe: RecipeProvider {

    let type = RecipeType.intervalNotify
    let name = "Repeating Reminder"
    let triggerIcon = "repeat"
    let actionIcon = "bell"
    let description = "Show a notification every N minutes"
    let scriptKind = ScriptKind.appleScript

    let fields: [RecipeField] = [
        .textField(label: "Reminder message", placeholder: "Time to stretch!", key: "message"),
        .numberField(label: "Repeat every", placeholder: "30", unit: "minutes"),
    ]

    func validate(config: [String: String]) -> String? {
        guard let msg = config["message"], !msg.isEmpty else {
            return "Please enter a reminder message"
        }
        guard let minStr = config["interval"], let mins = Int(minStr), mins > 0 else {
            return "Please enter a number of minutes (must be > 0)"
        }
        return nil
    }

    func generateScript(config: [String: String]) -> String {
        let message = config["message"] ?? "Reminder"
        // Escape quotes for AppleScript string
        let escaped = message.replacingOccurrences(of: "\"", with: "\\\"")
        return """
        display notification "\(escaped)" with title "Mac Automata"
        """
    }

    func sentence(config: [String: String]) -> String {
        let message = config["message"] ?? "a reminder"
        let minutes = config["interval"] ?? "30"
        return "Every \(minutes) min, remind: \"\(message)\""
    }

    func plistTriggerEntries(config: [String: String]) -> [String: Any] {
        let minutes = Int(config["interval"] ?? "30") ?? 30
        let seconds = minutes * 60
        return ["StartInterval": seconds]
    }
}

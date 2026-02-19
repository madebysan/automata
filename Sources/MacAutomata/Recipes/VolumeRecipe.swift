import Foundation

// Recipe: Set system volume on a schedule.
// Uses AppleScript to set the output volume level.
struct VolumeRecipe: RecipeProvider {

    let type = RecipeType.volume
    let name = "Set Volume"
    let triggerIcon = "clock"
    let actionIcon = "speaker.wave.2"
    let description = "Change system volume at a set time"
    let scriptKind = ScriptKind.appleScript

    let fields: [RecipeField] = [
        .numberField(label: "Volume level", placeholder: "50", unit: "% (0-100)"),
        .timePicker(label: "Time"),
        .weekdayPicker(label: "Days"),
    ]

    func validate(config: [String: String]) -> String? {
        guard let volStr = config["volume"], let vol = Int(volStr),
              vol >= 0, vol <= 100 else {
            return "Please enter a volume level between 0 and 100"
        }
        guard config["hour"] != nil, config["minute"] != nil else {
            return "Please set a time"
        }
        return nil
    }

    func generateScript(config: [String: String]) -> String {
        // AppleScript volume goes 0-100
        let volume = config["volume"] ?? "50"
        return """
        set volume output volume \(volume)
        """
    }

    func sentence(config: [String: String]) -> String {
        let volume = config["volume"] ?? "50"
        let time = formatTime(config)
        let days = formatDays(config)
        return "\(days) at \(time), set volume to \(volume)%"
    }

    func plistTriggerEntries(config: [String: String]) -> [String: Any] {
        return calendarTrigger(config)
    }
}

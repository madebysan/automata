import Foundation

// One configured automation: a trigger + an action.
// Example: "Every weekday at 9am" (trigger) + "open Xcode" (action).
struct Automation: Codable, Identifiable {

    /// Unique identifier (short hex string).
    let id: String

    /// The "When" part.
    let triggerType: TriggerType
    var triggerConfig: [String: String]

    /// The "Do this" part.
    let actionType: ActionType
    var actionConfig: [String: String]

    /// Whether this automation is currently active (plist loaded).
    var isEnabled: Bool

    /// When this automation was created.
    let createdAt: Date

    /// When this automation last ran.
    var lastRunAt: Date?

    /// Optional user-provided name. If nil, uses the auto-generated sentence.
    var customName: String?

    /// Create a new automation with a generated short ID.
    init(
        triggerType: TriggerType,
        triggerConfig: [String: String],
        actionType: ActionType,
        actionConfig: [String: String],
        customName: String? = nil
    ) {
        self.id = String(UUID().uuidString.prefix(8)).lowercased()
        self.triggerType = triggerType
        self.triggerConfig = triggerConfig
        self.actionType = actionType
        self.actionConfig = actionConfig
        self.isEnabled = true
        self.createdAt = Date()
        self.lastRunAt = nil
        self.customName = customName
    }

    /// The display name: custom name or auto-generated sentence.
    var displayName: String {
        if let name = customName, !name.isEmpty { return name }
        return sentence
    }

    /// The full sentence: "Every weekday at 9:00 AM, open Xcode and Figma"
    var sentence: String {
        let when = triggerType.sentenceFragment(config: triggerConfig)
        let what = actionType.sentenceFragment(config: actionConfig)
        return "\(when), \(what)"
    }

    /// Launchd plist label for this automation.
    var plistLabel: String {
        "com.macautomata.\(triggerType.rawValue)-\(actionType.rawValue)-\(id)"
    }
}

import Foundation

// One configured automation instance.
// Example: "Open Xcode at 9am weekdays" is one Automation
// backed by the OpenApps recipe with specific config values.
struct Automation: Codable, Identifiable {

    /// Unique identifier (short UUID, e.g. "a3f8b2")
    let id: String

    /// Which recipe this automation uses.
    let recipeType: RecipeType

    /// User-provided configuration values.
    /// Keys match the recipe's field definitions.
    /// Example: ["apps": "Xcode,Figma", "hour": "9", "minute": "0", "weekdays": "1,2,3,4,5"]
    var config: [String: String]

    /// Whether this automation is currently active (plist loaded).
    var isEnabled: Bool

    /// When this automation was created.
    let createdAt: Date

    /// When this automation last ran (updated by the activity log).
    var lastRunAt: Date?

    /// Optional user-provided name. If nil, uses the auto-generated sentence.
    var customName: String?

    /// Create a new automation with a generated short ID.
    init(recipeType: RecipeType, config: [String: String], customName: String? = nil) {
        // 6-char hex ID — short enough for plist labels, unique enough for personal use
        self.id = String(UUID().uuidString.prefix(8)).lowercased()
        self.recipeType = recipeType
        self.config = config
        self.isEnabled = true
        self.createdAt = Date()
        self.lastRunAt = nil
        self.customName = customName
    }

    /// The display name: custom name if set, otherwise the auto-generated sentence.
    var displayName: String {
        if let name = customName, !name.isEmpty {
            return name
        }
        return RecipeRegistry.provider(for: recipeType)?.sentence(config: config)
            ?? "\(recipeType.rawValue) automation"
    }

    /// The launchd plist label for this automation.
    var plistLabel: String {
        FileLocations.plistLabel(type: recipeType.rawValue, id: id)
    }
}

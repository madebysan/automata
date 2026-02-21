import Foundation

// The manifest.json schema.
// Stores all automations and app-level settings.
struct Manifest: Codable {
    var automations: [Automation]
    var appVersion: String
    var lastSaved: Date
    var isPaused: Bool
    var pausedAutomationIds: [String]

    static func empty() -> Manifest {
        Manifest(automations: [], appVersion: "0.2.0", lastSaved: Date(),
                 isPaused: false, pausedAutomationIds: [])
    }

    // Custom decoder so existing manifest.json files without pause fields don't crash
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        automations = try container.decode([Automation].self, forKey: .automations)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        lastSaved = try container.decode(Date.self, forKey: .lastSaved)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        pausedAutomationIds = try container.decodeIfPresent([String].self, forKey: .pausedAutomationIds) ?? []
    }

    init(automations: [Automation], appVersion: String, lastSaved: Date,
         isPaused: Bool = false, pausedAutomationIds: [String] = []) {
        self.automations = automations
        self.appVersion = appVersion
        self.lastSaved = lastSaved
        self.isPaused = isPaused
        self.pausedAutomationIds = pausedAutomationIds
    }
}

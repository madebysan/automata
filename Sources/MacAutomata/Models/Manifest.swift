import Foundation

// The manifest.json schema.
// Stores all automations and app-level settings.
struct Manifest: Codable {
    var automations: [Automation]
    var appVersion: String
    var lastSaved: Date

    static func empty() -> Manifest {
        Manifest(automations: [], appVersion: "0.2.0", lastSaved: Date())
    }
}

import Foundation

// The manifest.json schema.
// Stores all automations and app-level settings.
// Saved to ~/.mac-automata/manifest.json.
struct Manifest: Codable {

    /// All configured automations.
    var automations: [Automation]

    /// App version that last wrote this manifest (for future migrations).
    var appVersion: String

    /// When the manifest was last saved.
    var lastSaved: Date

    /// Create an empty manifest for first launch.
    static func empty() -> Manifest {
        Manifest(
            automations: [],
            appVersion: "0.1.0",
            lastSaved: Date()
        )
    }
}

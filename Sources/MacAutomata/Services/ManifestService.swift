import Foundation

// Reads and writes the manifest.json file.
// This is the single source of truth for all automation configs.
// The manifest lives at ~/.mac-automata/manifest.json.
class ManifestService {

    /// Shared instance used across the app.
    static let shared = ManifestService()

    /// The current in-memory manifest.
    private(set) var manifest: Manifest

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        // Load existing manifest or create a fresh one
        if let data = try? Data(contentsOf: FileLocations.manifestFile),
           let loaded = try? decoder.decode(Manifest.self, from: data) {
            self.manifest = loaded
            Log.info("Loaded manifest with \(loaded.automations.count) automations")
        } else {
            self.manifest = Manifest.empty()
            Log.info("Created new empty manifest")
        }
    }

    // MARK: - CRUD

    /// Add a new automation and save.
    @discardableResult
    func add(_ automation: Automation) -> Automation {
        manifest.automations.append(automation)
        save()
        Log.info("Added automation: \(automation.displayName) [\(automation.id)]")
        return automation
    }

    /// Update an existing automation by ID and save.
    func update(_ automation: Automation) {
        if let index = manifest.automations.firstIndex(where: { $0.id == automation.id }) {
            manifest.automations[index] = automation
            save()
            Log.info("Updated automation: \(automation.displayName) [\(automation.id)]")
        }
    }

    /// Remove an automation by ID and save.
    func remove(id: String) {
        if let index = manifest.automations.firstIndex(where: { $0.id == id }) {
            let name = manifest.automations[index].displayName
            manifest.automations.remove(at: index)
            save()
            Log.info("Removed automation: \(name) [\(id)]")
        }
    }

    /// Find an automation by ID.
    func automation(byId id: String) -> Automation? {
        manifest.automations.first { $0.id == id }
    }

    /// All automations, sorted by creation date (newest first).
    var allAutomations: [Automation] {
        manifest.automations.sorted { $0.createdAt > $1.createdAt }
    }

    /// Only enabled automations.
    var enabledAutomations: [Automation] {
        manifest.automations.filter { $0.isEnabled }
    }

    // MARK: - Toggle

    /// Toggle an automation's enabled state and save.
    func toggleEnabled(id: String) -> Bool {
        if let index = manifest.automations.firstIndex(where: { $0.id == id }) {
            manifest.automations[index].isEnabled.toggle()
            let newState = manifest.automations[index].isEnabled
            save()
            Log.info("Toggled \(id) -> \(newState ? "enabled" : "disabled")")
            return newState
        }
        return false
    }

    // MARK: - Pause / Resume

    /// Pause all enabled automations. Saves their IDs so resumeAll() can restore them.
    func pauseAll() {
        let enabledIds = manifest.automations.filter { $0.isEnabled }.map { $0.id }
        manifest.pausedAutomationIds = enabledIds
        manifest.isPaused = true
        // Disable each in launchd without changing isEnabled on the automations
        for id in enabledIds {
            if let automation = automation(byId: id) {
                LaunchdService.disable(automation: automation)
            }
        }
        save()
        Log.info("Paused all automations (\(enabledIds.count) disabled)")
    }

    /// Resume previously paused automations. Only re-enables ones that still exist and are still isEnabled.
    func resumeAll() {
        let idsToResume = manifest.pausedAutomationIds
        manifest.isPaused = false
        manifest.pausedAutomationIds = []
        for id in idsToResume {
            if let automation = automation(byId: id), automation.isEnabled {
                _ = LaunchdService.enable(automation: automation)
            }
        }
        save()
        Log.info("Resumed automations (\(idsToResume.count) candidates)")
    }

    // MARK: - Persistence

    /// Write the manifest to disk.
    func save() {
        manifest.lastSaved = Date()
        do {
            let data = try encoder.encode(manifest)
            try data.write(to: FileLocations.manifestFile, options: .atomic)
        } catch {
            Log.error("Failed to save manifest: \(error.localizedDescription)")
        }
    }

    /// Force reload from disk (useful if another process modified the file).
    func reload() {
        if let data = try? Data(contentsOf: FileLocations.manifestFile),
           let loaded = try? decoder.decode(Manifest.self, from: data) {
            self.manifest = loaded
        }
    }
}

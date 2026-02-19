import Foundation

// Writes scripts to disk that launchd will execute.
// Handles both AppleScript (.scpt) and shell script (.sh) files.
// Shell scripts get chmod +x automatically.
enum ScriptService {

    /// Write a script file for an automation. Returns the path to the script.
    @discardableResult
    static func install(automation: Automation) -> URL? {
        guard let recipe = RecipeRegistry.provider(for: automation.recipeType) else {
            Log.error("No recipe provider for \(automation.recipeType.rawValue)")
            return nil
        }

        let content = recipe.generateScript(config: automation.config)
        let ext = recipe.scriptKind == .appleScript ? "scpt" : "sh"
        let path = FileLocations.scriptPath(
            type: automation.recipeType.rawValue,
            id: automation.id,
            extension: ext
        )

        do {
            try content.write(to: path, atomically: true, encoding: .utf8)

            // Shell scripts need execute permission
            if recipe.scriptKind == .shellScript {
                let fm = FileManager.default
                var attributes = try fm.attributesOfItem(atPath: path.path)
                // Set 0755 — owner rwx, group rx, other rx
                attributes[.posixPermissions] = 0o755
                try fm.setAttributes(attributes, ofItemAtPath: path.path)
            }

            Log.info("Wrote script: \(path.lastPathComponent)")
            return path
        } catch {
            Log.error("Failed to write script: \(error.localizedDescription)")
            return nil
        }
    }

    /// Delete the script file for an automation.
    static func uninstall(automation: Automation) {
        guard let recipe = RecipeRegistry.provider(for: automation.recipeType) else { return }
        let ext = recipe.scriptKind == .appleScript ? "scpt" : "sh"
        let path = FileLocations.scriptPath(
            type: automation.recipeType.rawValue,
            id: automation.id,
            extension: ext
        )
        try? FileManager.default.removeItem(at: path)
        Log.info("Removed script: \(path.lastPathComponent)")
    }

    /// Get the path to an automation's script (whether it exists or not).
    static func scriptPath(for automation: Automation) -> URL? {
        guard let recipe = RecipeRegistry.provider(for: automation.recipeType) else { return nil }
        let ext = recipe.scriptKind == .appleScript ? "scpt" : "sh"
        return FileLocations.scriptPath(
            type: automation.recipeType.rawValue,
            id: automation.id,
            extension: ext
        )
    }
}

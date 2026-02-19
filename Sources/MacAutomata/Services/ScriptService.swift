import Foundation

// Writes scripts to disk that launchd will execute.
enum ScriptService {

    @discardableResult
    static func install(automation: Automation) -> URL? {
        let content = automation.actionType.generateScript(
            config: automation.actionConfig,
            triggerConfig: automation.triggerConfig
        )
        let ext = automation.actionType.scriptExtension
        let path = FileLocations.scriptURL(for: automation, extension: ext)

        do {
            try content.write(to: path, atomically: true, encoding: .utf8)
            // Shell scripts need execute permission
            if !automation.actionType.isAppleScript {
                var attrs = try FileManager.default.attributesOfItem(atPath: path.path)
                attrs[.posixPermissions] = 0o755
                try FileManager.default.setAttributes(attrs, ofItemAtPath: path.path)
            }
            Log.info("Wrote script: \(path.lastPathComponent)")
            return path
        } catch {
            Log.error("Failed to write script: \(error.localizedDescription)")
            return nil
        }
    }

    static func uninstall(automation: Automation) {
        let ext = automation.actionType.scriptExtension
        let path = FileLocations.scriptURL(for: automation, extension: ext)
        try? FileManager.default.removeItem(at: path)
    }
}

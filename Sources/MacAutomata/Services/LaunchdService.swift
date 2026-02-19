import Foundation

// Manages launchd plists for automations.
// Full lifecycle: generate plist -> write to ~/Library/LaunchAgents/ ->
// launchctl load/unload -> clean up on delete.
enum LaunchdService {

    // MARK: - Install / Uninstall

    /// Install an automation: write script, generate plist, load it.
    static func install(automation: Automation) -> Bool {
        // Step 1: Write the script file
        guard let scriptPath = ScriptService.install(automation: automation) else {
            return false
        }

        // Step 2: Build the plist
        let label = automation.plistLabel
        let triggerEntries = automation.triggerType.plistEntries(config: automation.triggerConfig)

        let programArgs: [String]
        if automation.actionType.isAppleScript {
            programArgs = ["/usr/bin/osascript", scriptPath.path]
        } else {
            programArgs = ["/bin/bash", scriptPath.path]
        }

        var plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArgs,
        ]

        // Merge trigger-specific entries
        for (key, value) in triggerEntries {
            plist[key] = value
        }

        // Logging
        let logPath = FileLocations.logsDir.path + "/\(label).log"
        plist["StandardOutPath"] = logPath
        plist["StandardErrorPath"] = logPath

        // Step 3: Write plist
        let plistPath = FileLocations.plistURL(for: automation)

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0
            )
            try data.write(to: plistPath, options: .atomic)
            Log.info("Wrote plist: \(plistPath.lastPathComponent)")
        } catch {
            Log.error("Failed to write plist: \(error.localizedDescription)")
            return false
        }

        // Step 4: Load
        return launchctlLoad(plistPath: plistPath)
    }

    /// Uninstall an automation: unload plist, delete files.
    static func uninstall(automation: Automation) {
        let plistPath = FileLocations.plistURL(for: automation)
        launchctlUnload(plistPath: plistPath)
        try? FileManager.default.removeItem(at: plistPath)
        ScriptService.uninstall(automation: automation)
        Log.info("Uninstalled: \(automation.plistLabel)")
    }

    // MARK: - Enable / Disable

    static func enable(automation: Automation) -> Bool {
        let plistPath = FileLocations.plistURL(for: automation)
        if !FileManager.default.fileExists(atPath: plistPath.path) {
            return install(automation: automation)
        }
        return launchctlLoad(plistPath: plistPath)
    }

    static func disable(automation: Automation) {
        launchctlUnload(plistPath: FileLocations.plistURL(for: automation))
    }

    // MARK: - Bulk

    static func removeAll() {
        let fm = FileManager.default
        let prefix = "com.macautomata."
        if let files = try? fm.contentsOfDirectory(at: FileLocations.launchAgentsDir, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix(prefix) {
                launchctlUnload(plistPath: file)
                try? fm.removeItem(at: file)
            }
        }
        if let files = try? fm.contentsOfDirectory(at: FileLocations.scriptsDir, includingPropertiesForKeys: nil) {
            for file in files { try? fm.removeItem(at: file) }
        }
        Log.info("Removed all automations")
    }

    // MARK: - Private

    @discardableResult
    private static func launchctlLoad(plistPath: URL) -> Bool {
        let output = runProcess("/bin/launchctl", arguments: ["load", plistPath.path])
        if output.isEmpty || output.contains("already loaded") {
            Log.info("Loaded: \(plistPath.lastPathComponent)")
            return true
        }
        Log.error("launchctl load: \(output)")
        return false
    }

    private static func launchctlUnload(plistPath: URL) {
        let _ = runProcess("/bin/launchctl", arguments: ["unload", plistPath.path])
    }

    private static func runProcess(_ path: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Error: \(error.localizedDescription)"
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

import Foundation

// Manages launchd plists for automations.
// Full lifecycle: generate plist XML -> write to ~/Library/LaunchAgents/ ->
// launchctl load/unload -> clean up on delete.
//
// Uses legacy load/unload commands which still work on macOS 13+
// and are simpler than bootstrap/bootout.
enum LaunchdService {

    // MARK: - Install / Uninstall

    /// Install an automation: write script, generate plist, load it.
    static func install(automation: Automation) -> Bool {
        // Step 1: Write the script file
        guard let scriptPath = ScriptService.install(automation: automation) else {
            return false
        }

        // Step 2: Build the plist dictionary
        guard let recipe = RecipeRegistry.provider(for: automation.recipeType) else {
            Log.error("No recipe for type: \(automation.recipeType.rawValue)")
            return false
        }

        let label = automation.plistLabel
        let schedule = recipe.scheduleDict(config: automation.config)

        // Build ProgramArguments based on script type
        let programArgs: [String]
        switch recipe.scriptKind {
        case .appleScript:
            programArgs = ["/usr/bin/osascript", scriptPath.path]
        case .shellScript:
            programArgs = ["/bin/bash", scriptPath.path]
        }

        var plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArgs,
            "StartCalendarInterval": schedule,
        ]

        // Add stdout/stderr logging
        let logPath = FileLocations.logsDir.path + "/\(label).log"
        plist["StandardOutPath"] = logPath
        plist["StandardErrorPath"] = logPath

        // Step 3: Write the plist file
        let plistPath = FileLocations.plistPath(
            type: automation.recipeType.rawValue,
            id: automation.id
        )

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: plistPath, options: .atomic)
            Log.info("Wrote plist: \(plistPath.lastPathComponent)")
        } catch {
            Log.error("Failed to write plist: \(error.localizedDescription)")
            return false
        }

        // Step 4: Load it with launchctl
        return launchctlLoad(plistPath: plistPath)
    }

    /// Uninstall an automation: unload plist, delete plist and script files.
    static func uninstall(automation: Automation) {
        let plistPath = FileLocations.plistPath(
            type: automation.recipeType.rawValue,
            id: automation.id
        )

        // Unload first (ignore errors if not loaded)
        launchctlUnload(plistPath: plistPath)

        // Delete plist
        try? FileManager.default.removeItem(at: plistPath)
        Log.info("Removed plist: \(plistPath.lastPathComponent)")

        // Delete script
        ScriptService.uninstall(automation: automation)
    }

    // MARK: - Enable / Disable

    /// Enable an automation (load its existing plist).
    static func enable(automation: Automation) -> Bool {
        let plistPath = FileLocations.plistPath(
            type: automation.recipeType.rawValue,
            id: automation.id
        )
        guard FileManager.default.fileExists(atPath: plistPath.path) else {
            // Plist doesn't exist — need to do a full install
            return install(automation: automation)
        }
        return launchctlLoad(plistPath: plistPath)
    }

    /// Disable an automation (unload plist but keep files).
    static func disable(automation: Automation) {
        let plistPath = FileLocations.plistPath(
            type: automation.recipeType.rawValue,
            id: automation.id
        )
        launchctlUnload(plistPath: plistPath)
    }

    // MARK: - Status

    /// Check if an automation's plist is currently loaded in launchd.
    static func isLoaded(automation: Automation) -> Bool {
        let label = automation.plistLabel
        let output = runProcess("/bin/launchctl", arguments: ["list"])
        return output.contains(label)
    }

    /// Remove ALL Mac Automata plists and scripts. Nuclear option.
    static func removeAll() {
        let fm = FileManager.default
        let prefix = "com.macautomata."

        // Find and unload all our plists
        if let files = try? fm.contentsOfDirectory(
            at: FileLocations.launchAgentsDir,
            includingPropertiesForKeys: nil
        ) {
            for file in files where file.lastPathComponent.hasPrefix(prefix) {
                launchctlUnload(plistPath: file)
                try? fm.removeItem(at: file)
                Log.info("Removed plist: \(file.lastPathComponent)")
            }
        }

        // Remove all scripts
        if let files = try? fm.contentsOfDirectory(
            at: FileLocations.scriptsDir,
            includingPropertiesForKeys: nil
        ) {
            for file in files {
                try? fm.removeItem(at: file)
            }
        }

        Log.info("Removed all Mac Automata automations")
    }

    // MARK: - Private helpers

    @discardableResult
    private static func launchctlLoad(plistPath: URL) -> Bool {
        let output = runProcess("/bin/launchctl", arguments: ["load", plistPath.path])
        if output.isEmpty || output.contains("service already loaded") {
            Log.info("Loaded: \(plistPath.lastPathComponent)")
            return true
        }
        Log.error("launchctl load failed: \(output)")
        return false
    }

    private static func launchctlUnload(plistPath: URL) {
        let output = runProcess("/bin/launchctl", arguments: ["unload", plistPath.path])
        if output.isEmpty || output.contains("Could not find") {
            Log.info("Unloaded: \(plistPath.lastPathComponent)")
        } else {
            Log.warn("launchctl unload: \(output)")
        }
    }

    /// Run a process and capture its combined stdout+stderr output.
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
            return "Process error: \(error.localizedDescription)"
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

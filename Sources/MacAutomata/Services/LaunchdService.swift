import Foundation

// Manages launchd plists for automations.
// Full lifecycle: generate plist -> write to ~/Library/LaunchAgents/ ->
// launchctl load/unload -> clean up on delete.
enum LaunchdService {

    // MARK: - Install / Uninstall

    /// Install an automation: write script, generate plist, load it.
    static func install(automation: Automation) -> Bool {
        FileLocations.ensureDirectoriesExist()

        if automation.triggerType == .timeRange {
            return installTimeRange(automation: automation)
        }

        guard let scriptPath = ScriptService.install(automation: automation) else { return false }

        let label = automation.plistLabel
        let triggerEntries = automation.triggerType.plistEntries(config: automation.triggerConfig)
        let programArgs: [String] = automation.actionType.isAppleScript
            ? ["/usr/bin/osascript", scriptPath.path]
            : ["/bin/bash", scriptPath.path]

        let logPath = FileLocations.logsDir.path + "/\(label).log"
        var plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArgs,
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath,
        ]
        for (key, value) in triggerEntries { plist[key] = value }

        let plistPath = FileLocations.plistURL(for: automation)
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistPath, options: .atomic)
            Log.info("Wrote plist: \(plistPath.lastPathComponent)")
        } catch {
            Log.error("Failed to write plist: \(error.localizedDescription)")
            return false
        }
        return launchctlLoad(plistPath: plistPath)
    }

    /// Install a time range automation as two plists: one at start time, one at end time.
    private static func installTimeRange(automation: Automation) -> Bool {
        guard let startScriptPath = ScriptService.install(automation: automation),
              let endScriptPath = ScriptService.installRevert(automation: automation) else { return false }

        let tc = automation.triggerConfig
        let startH = Int(tc["startHour"] ?? "9") ?? 9
        let startM = Int(tc["startMinute"] ?? "0") ?? 0
        let endH   = Int(tc["endHour"] ?? "18") ?? 18
        let endM   = Int(tc["endMinute"] ?? "0") ?? 0

        let baseLabel = automation.plistLabel
        let startLabel = "\(baseLabel)-start"
        let endLabel   = "\(baseLabel)-end"

        let startArgs: [String] = automation.actionType.isAppleScript
            ? ["/usr/bin/osascript", startScriptPath.path]
            : ["/bin/bash", startScriptPath.path]
        let endArgs: [String] = automation.actionType.isRevertAppleScript
            ? ["/usr/bin/osascript", endScriptPath.path]
            : ["/bin/bash", endScriptPath.path]

        let startInterval = calendarInterval(hour: startH, minute: startM, triggerConfig: tc)
        let endInterval   = calendarInterval(hour: endH,   minute: endM,   triggerConfig: tc)

        let startPlist: [String: Any] = [
            "Label": startLabel,
            "ProgramArguments": startArgs,
            "StartCalendarInterval": startInterval,
            "StandardOutPath":  FileLocations.logsDir.path + "/\(startLabel).log",
            "StandardErrorPath": FileLocations.logsDir.path + "/\(startLabel).log",
        ]
        let endPlist: [String: Any] = [
            "Label": endLabel,
            "ProgramArguments": endArgs,
            "StartCalendarInterval": endInterval,
            "StandardOutPath":  FileLocations.logsDir.path + "/\(endLabel).log",
            "StandardErrorPath": FileLocations.logsDir.path + "/\(endLabel).log",
        ]

        let startPath = FileLocations.launchAgentsDir.appendingPathComponent("\(startLabel).plist")
        let endPath   = FileLocations.launchAgentsDir.appendingPathComponent("\(endLabel).plist")

        do {
            let d1 = try PropertyListSerialization.data(fromPropertyList: startPlist, format: .xml, options: 0)
            try d1.write(to: startPath, options: .atomic)
            let d2 = try PropertyListSerialization.data(fromPropertyList: endPlist, format: .xml, options: 0)
            try d2.write(to: endPath, options: .atomic)
            Log.info("Wrote time range plists: \(startLabel), \(endLabel)")
        } catch {
            Log.error("Failed to write time range plists: \(error.localizedDescription)")
            return false
        }

        let r1 = launchctlLoad(plistPath: startPath)
        let r2 = launchctlLoad(plistPath: endPath)
        return r1 && r2
    }

    /// Uninstall an automation: unload plist, delete files.
    static func uninstall(automation: Automation) {
        if automation.triggerType == .timeRange {
            let base = automation.plistLabel
            let startPath = FileLocations.launchAgentsDir.appendingPathComponent("\(base)-start.plist")
            let endPath   = FileLocations.launchAgentsDir.appendingPathComponent("\(base)-end.plist")
            launchctlUnload(plistPath: startPath)
            launchctlUnload(plistPath: endPath)
            try? FileManager.default.removeItem(at: startPath)
            try? FileManager.default.removeItem(at: endPath)
            ScriptService.uninstall(automation: automation)
            ScriptService.uninstallRevert(automation: automation)
        } else {
            let plistPath = FileLocations.plistURL(for: automation)
            launchctlUnload(plistPath: plistPath)
            try? FileManager.default.removeItem(at: plistPath)
            ScriptService.uninstall(automation: automation)
        }
        Log.info("Uninstalled: \(automation.plistLabel)")
    }

    // MARK: - Enable / Disable

    static func enable(automation: Automation) -> Bool {
        if automation.triggerType == .timeRange {
            let base = automation.plistLabel
            let startPath = FileLocations.launchAgentsDir.appendingPathComponent("\(base)-start.plist")
            let endPath   = FileLocations.launchAgentsDir.appendingPathComponent("\(base)-end.plist")
            if !FileManager.default.fileExists(atPath: startPath.path) {
                return install(automation: automation)
            }
            return launchctlLoad(plistPath: startPath) && launchctlLoad(plistPath: endPath)
        }
        let plistPath = FileLocations.plistURL(for: automation)
        if !FileManager.default.fileExists(atPath: plistPath.path) {
            return install(automation: automation)
        }
        return launchctlLoad(plistPath: plistPath)
    }

    static func disable(automation: Automation) {
        if automation.triggerType == .timeRange {
            let base = automation.plistLabel
            launchctlUnload(plistPath: FileLocations.launchAgentsDir.appendingPathComponent("\(base)-start.plist"))
            launchctlUnload(plistPath: FileLocations.launchAgentsDir.appendingPathComponent("\(base)-end.plist"))
            return
        }
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

    /// Build a StartCalendarInterval value for a given hour/minute + optional weekdays.
    private static func calendarInterval(hour: Int, minute: Int, triggerConfig: [String: String]) -> Any {
        let base = ["Hour": hour, "Minute": minute] as [String: Int]
        if let daysStr = triggerConfig["weekdays"], !daysStr.isEmpty {
            let days = daysStr.split(separator: ",").compactMap { Int($0) }
            if !days.isEmpty && days.count < 7 {
                return days.map { ["Hour": hour, "Minute": minute, "Weekday": $0] as [String: Int] }
            }
        }
        return base
    }

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

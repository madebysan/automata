import Cocoa

// Checks and requests macOS permissions needed for automations.
// AppleScript automations targeting System Events or Finder will
// trigger a consent dialog on first run. This service can proactively
// test permissions so the user isn't surprised when an automation fires.
enum PermissionService {

    /// Test whether we can send Apple Events to System Events.
    /// Triggers the macOS permission prompt if not yet granted.
    static func requestAutomationPermission() {
        // Running a harmless AppleScript that targets System Events
        // will trigger the consent dialog if permission hasn't been granted yet
        let script = """
        tell application "System Events"
            return name of current user
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        // Suppress output — we only care about triggering the prompt
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                Log.info("Automation permission granted for System Events")
            } else {
                Log.warn("Automation permission may not be granted yet")
            }
        } catch {
            Log.error("Failed to check automation permission: \(error.localizedDescription)")
        }
    }

    /// Test whether we can target Finder (needed for Empty Trash).
    static func requestFinderPermission() {
        let script = """
        tell application "Finder"
            return name of startup disk
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                Log.info("Automation permission granted for Finder")
            }
        } catch {
            Log.error("Failed to check Finder permission: \(error.localizedDescription)")
        }
    }

    /// Run all permission checks. Call on first launch or from settings.
    static func requestAllPermissions() {
        Log.info("Requesting automation permissions...")
        requestAutomationPermission()
        requestFinderPermission()
    }
}

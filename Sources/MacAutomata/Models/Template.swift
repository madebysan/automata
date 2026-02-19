import Cocoa

// A pre-built automation template that users can add with one click.
// Templates pre-fill the trigger + action + most config values.
// Fields left blank (empty string) prompt the user to fill them in.
struct Template {
    let id: String
    let name: String
    let subtitle: String
    let icon: String           // SF Symbol name
    let color: NSColor
    let category: TemplateCategory
    let triggerType: TriggerType
    let triggerConfig: [String: String]
    let actionType: ActionType
    let actionConfig: [String: String]

    /// Whether this template needs user input before saving.
    /// True if any config value is empty string (placeholder for user input).
    var needsInput: Bool {
        triggerConfig.values.contains("") || actionConfig.values.contains("")
    }
}

enum TemplateCategory: String, CaseIterable {
    case routines = "Routines"
    case focus = "Focus & Wind Down"
    case volume = "Volume"
    case reminders = "Reminders"
    case files = "File Organization"
    case web = "Web & Links"
    case drives = "External Drives"
}

// All 20 built-in templates.
enum TemplateLibrary {

    static let all: [Template] = [

        // ── Routines ──

        Template(
            id: "morning-workspace",
            name: "Morning Workspace",
            subtitle: "Open your chosen apps at 9 AM every weekday",
            icon: "sun.and.horizon",
            color: .systemOrange,
            category: .routines,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "9", "minute": "0", "weekdays": "2,3,4,5,6"],
            actionType: .openApps,
            actionConfig: ["apps": ""]
        ),
        Template(
            id: "daily-journal",
            name: "Open Daily Journal",
            subtitle: "Open a file of your choice at 8 AM every day",
            icon: "note.text",
            color: .systemYellow,
            category: .routines,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "8", "minute": "0", "weekdays": "2,3,4,5,6,7,1"],
            actionType: .openFile,
            actionConfig: ["filePath": ""]
        ),
        Template(
            id: "startup-apps",
            name: "Startup Apps",
            subtitle: "Open your chosen apps automatically when you log in",
            icon: "bolt.fill",
            color: .systemBlue,
            category: .routines,
            triggerType: .onLogin,
            triggerConfig: [:],
            actionType: .openApps,
            actionConfig: ["apps": ""]
        ),
        Template(
            id: "morning-music",
            name: "Morning Music",
            subtitle: "Play a song or playlist file when you log in",
            icon: "music.note",
            color: .systemPink,
            category: .routines,
            triggerType: .onLogin,
            triggerConfig: [:],
            actionType: .openFile,
            actionConfig: ["filePath": ""]
        ),

        // ── Focus & Wind Down ──

        Template(
            id: "end-of-day",
            name: "End of Day Shutdown",
            subtitle: "Quit your chosen apps at 6 PM every weekday",
            icon: "moon.stars",
            color: .systemIndigo,
            category: .focus,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "18", "minute": "0", "weekdays": "2,3,4,5,6"],
            actionType: .quitApps,
            actionConfig: ["apps": ""]
        ),
        Template(
            id: "focus-mode",
            name: "Focus Mode",
            subtitle: "Quit Messages, Slack, and Discord at 9 AM weekdays",
            icon: "eye.slash",
            color: .systemPurple,
            category: .focus,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "9", "minute": "0", "weekdays": "2,3,4,5,6"],
            actionType: .quitApps,
            actionConfig: ["apps": "Messages,Slack,Discord"]
        ),
        Template(
            id: "dark-mode-night",
            name: "Dark Mode at Night",
            subtitle: "Turn on Dark Mode at 8 PM every day",
            icon: "moon.fill",
            color: .systemIndigo,
            category: .focus,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "20", "minute": "0", "weekdays": "2,3,4,5,6,7,1"],
            actionType: .darkMode,
            actionConfig: ["mode": "dark"]
        ),
        Template(
            id: "light-mode-morning",
            name: "Light Mode in Morning",
            subtitle: "Turn on Light Mode at 7 AM every day",
            icon: "sun.max.fill",
            color: .systemYellow,
            category: .focus,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "7", "minute": "0", "weekdays": "2,3,4,5,6,7,1"],
            actionType: .darkMode,
            actionConfig: ["mode": "light"]
        ),

        // ── Volume ──

        Template(
            id: "quiet-hours",
            name: "Quiet Hours",
            subtitle: "Mute volume to 0% at 11 PM every day",
            icon: "speaker.slash",
            color: .systemGray,
            category: .volume,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "23", "minute": "0", "weekdays": "2,3,4,5,6,7,1"],
            actionType: .setVolume,
            actionConfig: ["volume": "0"]
        ),
        Template(
            id: "morning-volume",
            name: "Morning Volume",
            subtitle: "Set volume to 50% at 7 AM every day",
            icon: "speaker.wave.2",
            color: .systemGreen,
            category: .volume,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "7", "minute": "0", "weekdays": "2,3,4,5,6,7,1"],
            actionType: .setVolume,
            actionConfig: ["volume": "50"]
        ),

        // ── Reminders ──

        Template(
            id: "stretch-break",
            name: "Stretch Break",
            subtitle: "Every 30 min, notify: \"Time to stretch!\"",
            icon: "figure.stand",
            color: .systemGreen,
            category: .reminders,
            triggerType: .interval,
            triggerConfig: ["interval": "30"],
            actionType: .showNotification,
            actionConfig: ["message": "Time to stretch!"]
        ),
        Template(
            id: "hydration",
            name: "Hydration Reminder",
            subtitle: "Every 60 min, notify: \"Drink water\"",
            icon: "drop.fill",
            color: .systemCyan,
            category: .reminders,
            triggerType: .interval,
            triggerConfig: ["interval": "60"],
            actionType: .showNotification,
            actionConfig: ["message": "Drink water \u{1F4A7}"]
        ),
        Template(
            id: "eye-break",
            name: "Eye Break (20-20-20)",
            subtitle: "Every 20 min, notify: \"Look away for 20 seconds\"",
            icon: "eye",
            color: .systemTeal,
            category: .reminders,
            triggerType: .interval,
            triggerConfig: ["interval": "20"],
            actionType: .showNotification,
            actionConfig: ["message": "Look away from screen for 20 seconds"]
        ),

        // ── File Organization ──

        Template(
            id: "screenshot-organizer",
            name: "Screenshot Organizer",
            subtitle: "When files appear on Desktop, move to Screenshots folder",
            icon: "camera.viewfinder",
            color: .systemOrange,
            category: .files,
            triggerType: .fileAppears,
            triggerConfig: ["watchFolder": NSHomeDirectory() + "/Desktop"],
            actionType: .moveFiles,
            actionConfig: ["destFolder": NSHomeDirectory() + "/Pictures/Screenshots"]
        ),
        Template(
            id: "downloads-sorter",
            name: "Downloads Sorter",
            subtitle: "When files appear in Downloads, move to a folder you pick",
            icon: "folder.badge.plus",
            color: .systemBlue,
            category: .files,
            triggerType: .fileAppears,
            triggerConfig: ["watchFolder": NSHomeDirectory() + "/Downloads"],
            actionType: .moveFiles,
            actionConfig: ["destFolder": ""]
        ),
        Template(
            id: "weekly-cleanup",
            name: "Weekly Downloads Cleanup",
            subtitle: "Every Sunday at 10 AM, delete files older than 30 days",
            icon: "folder.badge.minus",
            color: .systemTeal,
            category: .files,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "10", "minute": "0", "weekdays": "1"],
            actionType: .cleanDownloads,
            actionConfig: ["days": "30"]
        ),
        Template(
            id: "empty-trash",
            name: "Empty Trash Weekly",
            subtitle: "Every Friday at 5 PM, empty the Trash",
            icon: "trash",
            color: .systemGray,
            category: .files,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "17", "minute": "0", "weekdays": "6"],
            actionType: .emptyTrash,
            actionConfig: [:]
        ),

        // ── Web & Links ──

        Template(
            id: "daily-standup",
            name: "Daily Standup",
            subtitle: "Open a meeting URL at 9:30 AM every weekday",
            icon: "video",
            color: .systemGreen,
            category: .web,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "9", "minute": "30", "weekdays": "2,3,4,5,6"],
            actionType: .openURLs,
            actionConfig: ["urls": ""]
        ),
        Template(
            id: "weekly-review",
            name: "Weekly Review Sites",
            subtitle: "Open your dashboard URLs every Monday at 9 AM",
            icon: "globe",
            color: .systemIndigo,
            category: .web,
            triggerType: .scheduledTime,
            triggerConfig: ["hour": "9", "minute": "0", "weekdays": "2"],
            actionType: .openURLs,
            actionConfig: ["urls": ""]
        ),

        // ── External Drives ──

        Template(
            id: "backup-reminder",
            name: "Backup Reminder",
            subtitle: "When a drive is plugged in, notify: \"Time to back up!\"",
            icon: "externaldrive.badge.checkmark",
            color: .systemOrange,
            category: .drives,
            triggerType: .driveMount,
            triggerConfig: [:],
            actionType: .showNotification,
            actionConfig: ["message": "External drive connected \u{2014} time to back up!"]
        ),
    ]

    /// Templates grouped by category, in display order.
    static var grouped: [(category: TemplateCategory, templates: [Template])] {
        TemplateCategory.allCases.compactMap { cat in
            let items = all.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}

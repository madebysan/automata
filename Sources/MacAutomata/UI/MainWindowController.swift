import Cocoa
import UserNotifications

// The main window for creating and managing automations.
// Shows the recipe picker first, then the config view when a recipe is selected.
// After saving, installs the automation and returns to the menu bar.
class MainWindowController {

    private var window: NSWindow?
    private weak var statusBar: StatusBarController?

    init(statusBar: StatusBarController) {
        self.statusBar = statusBar
    }

    func show() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: Styles.mainWindowSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Mac Automata"
        w.center()
        w.isReleasedWhenClosed = false
        window = w

        showRecipePicker()

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Show the recipe picker (step 1).
    private func showRecipePicker() {
        let picker = RecipePickerView(frame: NSRect(origin: .zero, size: Styles.mainWindowSize))

        picker.onRecipePicked = { [weak self] recipe in
            self?.showRecipeConfig(recipe: recipe)
        }

        window?.contentView = picker
        window?.title = "Mac Automata — Choose a Recipe"
    }

    /// Show the config view for a specific recipe (step 2).
    private func showRecipeConfig(recipe: RecipeProvider) {
        let configView = RecipeConfigView(recipe: recipe)

        configView.onBack = { [weak self] in
            self?.showRecipePicker()
        }

        configView.onSave = { [weak self] automation in
            self?.saveAndInstall(automation)
        }

        window?.contentView = configView
        window?.title = "Mac Automata — \(recipe.name)"
    }

    /// Save the automation to the manifest and install it via launchd.
    private func saveAndInstall(_ automation: Automation) {
        // Save to manifest
        let saved = ManifestService.shared.add(automation)

        // Install plist + script
        let success = LaunchdService.install(automation: saved)

        if success {
            Log.info("Installed automation: \(saved.displayName)")
        } else {
            Log.error("Failed to install automation: \(saved.displayName)")
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Installation Failed"
            alert.informativeText = "The automation was saved but couldn't be loaded into launchd. Check the activity log for details."
            alert.alertStyle = .warning
            alert.runModal()
        }

        // Refresh menu bar and close window
        statusBar?.rebuildMenu()
        window?.close()

        // Show success notification
        showNotification(automation: saved)
    }

    private func showNotification(automation: Automation) {
        let content = UNMutableNotificationContent()
        content.title = "Automation Created"
        content.body = automation.displayName

        let request = UNNotificationRequest(
            identifier: "automation-created-\(automation.id)",
            content: content,
            trigger: nil // Deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}

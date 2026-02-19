import Cocoa
import UserNotifications

// The main window for creating automations.
// Shows the AutomationBuilder (When/Do builder).
class MainWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private(set) weak var statusBar: StatusBarController?

    init(statusBar: StatusBarController) {
        self.statusBar = statusBar
        super.init()
    }

    func show(editing automation: Automation? = nil) {
        NSApp.setActivationPolicy(.regular)

        if let existingWindow = window {
            existingWindow.contentView = nil
        }

        let w = window ?? {
            let w = NSWindow(
                contentRect: NSRect(origin: .zero, size: Styles.mainWindowSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            w.center()
            w.isReleasedWhenClosed = false
            w.delegate = self
            window = w
            return w
        }()

        let builder = AutomationBuilder(editing: automation)
        builder.onCancel = { [weak self] in
            self?.window?.close()
            NSApp.setActivationPolicy(.accessory)
        }
        builder.onSave = { [weak self] saved in
            self?.saveAndInstall(saved, isEdit: automation != nil)
        }

        w.contentView = builder
        w.title = automation != nil ? "Edit Automation" : "New Automation"
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func saveAndInstall(_ automation: Automation, isEdit: Bool) {
        if isEdit {
            // Uninstall old, update manifest, reinstall
            if let old = ManifestService.shared.automation(byId: automation.id) {
                LaunchdService.uninstall(automation: old)
            }
            ManifestService.shared.update(automation)
            if automation.isEnabled {
                _ = LaunchdService.install(automation: automation)
            }
        } else {
            let saved = ManifestService.shared.add(automation)
            _ = LaunchdService.install(automation: saved)
        }

        statusBar?.rebuildMenu()
        window?.close()
        NSApp.setActivationPolicy(.accessory)
    }
}

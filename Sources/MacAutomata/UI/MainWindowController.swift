import Cocoa
import UserNotifications

// The main window for creating automations.
// Shows the templates view first, opens the builder when a template
// is selected or when the user chooses "Custom".
class MainWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private(set) weak var statusBar: StatusBarController?

    init(statusBar: StatusBarController) {
        self.statusBar = statusBar
        super.init()
    }

    func show(editing automation: Automation? = nil) {
        NSApp.setActivationPolicy(.regular)

        let w = window ?? {
            let w = NSWindow(
                contentRect: NSRect(origin: .zero, size: Styles.mainWindowSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false
            )
            w.center()
            w.isReleasedWhenClosed = false
            w.delegate = self
            window = w
            return w
        }()

        if let automation = automation {
            showBuilder(editing: automation)
        } else {
            showTemplates()
        }

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Views

    private func showTemplates() {
        let templates = TemplatesView()

        templates.onTemplateSelected = { [weak self] template in
            if template.needsInput {
                // Open builder pre-filled so user can complete the missing fields
                let automation = Automation(
                    triggerType: template.triggerType,
                    triggerConfig: template.triggerConfig,
                    actionType: template.actionType,
                    actionConfig: template.actionConfig
                )
                self?.showBuilder(editing: automation)
            } else {
                // Fully configured — install immediately
                self?.quickInstall(template: template)
            }
        }

        templates.onCustom = { [weak self] in
            self?.showBuilder(editing: nil)
        }

        window?.contentView = templates
        window?.title = "New Automation"
    }

    private func showBuilder(editing automation: Automation?) {
        let builder = AutomationBuilder(editing: automation)

        builder.onCancel = { [weak self] in
            // Go back to templates (unless editing an existing saved automation)
            if automation != nil, ManifestService.shared.automation(byId: automation!.id) != nil {
                // Editing a saved automation — just close
                self?.window?.close()
                NSApp.setActivationPolicy(.accessory)
            } else {
                self?.showTemplates()
            }
        }

        builder.onSave = { [weak self] saved in
            let isEdit = ManifestService.shared.automation(byId: saved.id) != nil
            self?.saveAndInstall(saved, isEdit: isEdit)
        }

        window?.contentView = builder
        window?.title = automation != nil ? "Configure Automation" : "Custom Automation"
    }

    // MARK: - Install

    private func quickInstall(template: Template) {
        let automation = Automation(
            triggerType: template.triggerType,
            triggerConfig: template.triggerConfig,
            actionType: template.actionType,
            actionConfig: template.actionConfig
        )
        saveAndInstall(automation, isEdit: false)
    }

    private func saveAndInstall(_ automation: Automation, isEdit: Bool) {
        if isEdit {
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

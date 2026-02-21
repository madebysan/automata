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
        NSApp.setActivationPolicy(.accessory)

        let w = window ?? {
            let w = NSWindow(
                contentRect: NSRect(origin: .zero, size: Styles.mainWindowSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            w.center()
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 420, height: 400)
            w.delegate = self
            window = w
            return w
        }()

        if let automation = automation {
            showBuilder(editing: automation)
        } else {
            showTemplates()
        }

        sizeWindowToContent()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    /// Resize the window to fit its content, capped at 80% of screen height.
    private func sizeWindowToContent() {
        guard let w = window, let contentView = w.contentView else { return }

        // Let the layout pass complete
        contentView.layoutSubtreeIfNeeded()

        // Find the scroll view's document view to get the actual content height
        let contentHeight: CGFloat
        if let scrollView = contentView as? NSScrollView,
           let docView = scrollView.documentView {
            contentHeight = docView.frame.height
        } else if let scrollView = contentView.subviews.compactMap({ $0 as? NSScrollView }).first,
                  let docView = scrollView.documentView {
            contentHeight = docView.frame.height
        } else {
            contentHeight = contentView.fittingSize.height
        }

        // Add title bar height (~28pt)
        let titleBarHeight: CGFloat = 28
        let idealHeight = contentHeight + titleBarHeight

        // Cap at 80% of screen height
        let maxHeight = (NSScreen.main?.visibleFrame.height ?? 800) * 0.8
        let finalHeight = min(idealHeight, maxHeight)

        // Resize from top-left (keep the top edge in place)
        var frame = w.frame
        let oldTop = frame.origin.y + frame.size.height
        frame.size.height = finalHeight
        frame.size.width = max(frame.size.width, Styles.mainWindowSize.width)
        frame.origin.y = oldTop - finalHeight
        w.setFrame(frame, display: true, animate: true)
    }

    // MARK: - Views

    private func showTemplates() {
        let templates = TemplatesView()

        templates.onTemplateSelected = { [weak self] template in
            // Always open builder pre-filled so user can review and confirm before saving
            let automation = Automation(
                triggerType: template.triggerType,
                triggerConfig: template.triggerConfig,
                actionType: template.actionType,
                actionConfig: template.actionConfig
            )
            self?.showBuilder(editing: automation)
        }

        templates.onSuggestionSelected = { [weak self] suggestion in
            let automation = Automation(
                triggerType: suggestion.triggerType,
                triggerConfig: suggestion.triggerConfig,
                actionType: suggestion.actionType,
                actionConfig: suggestion.actionConfig
            )
            self?.showBuilder(editing: automation)
        }

        templates.onCustom = { [weak self] in
            self?.showBuilder(editing: nil)
        }

        window?.contentView = templates
        window?.title = "New Automation"
        DispatchQueue.main.async {
            // Don't auto-focus the NL text field — let the user click into it
            self.window?.makeFirstResponder(nil)
            self.sizeWindowToContent()
        }
    }

    private func showBuilder(editing automation: Automation?) {
        let builder = AutomationBuilder(editing: automation)

        builder.onCancel = { [weak self] in
            // Go back to templates (unless editing an existing saved automation)
            if let a = automation, ManifestService.shared.automation(byId: a.id) != nil {
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
        DispatchQueue.main.async { self.sizeWindowToContent() }
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

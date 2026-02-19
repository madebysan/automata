import Cocoa

// Manages the menu bar icon and dropdown menu.
class StatusBarController {

    private var statusItem: NSStatusItem!
    private var mainWindowController: MainWindowController?
    private var manageWindowController: ManageWindowController?

    init() {
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: "Mac Automata")
            button.image?.size = NSSize(width: Styles.statusBarIconSize, height: Styles.statusBarIconSize)
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        let automations = ManifestService.shared.allAutomations

        // Header
        let header = NSMenuItem(title: "Mac Automata", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let enabled = ManifestService.shared.enabledAutomations.count
        let total = automations.count
        let statusText = total == 0 ? "No automations yet" : "\(enabled) of \(total) active"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        // Automation list with toggles
        if !automations.isEmpty {
            for automation in automations {
                let item = NSMenuItem(
                    title: automation.displayName,
                    action: #selector(toggleAutomation(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = automation.id
                item.state = automation.isEnabled ? .on : .off
                if let img = NSImage(systemSymbolName: automation.actionType.icon, accessibilityDescription: automation.actionType.name) {
                    let config = NSImage.SymbolConfiguration(pointSize: Styles.sidebarIconSize, weight: .regular)
                    item.image = img.withSymbolConfiguration(config)
                }
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        // Add + Manage
        let addItem = menu.addItem(withTitle: "New Automation\u{2026}", action: #selector(openMainWindow), keyEquivalent: "n")
        addItem.target = self

        if !automations.isEmpty {
            let manageItem = menu.addItem(withTitle: "Manage Automations\u{2026}", action: #selector(openManageWindow), keyEquivalent: "m")
            manageItem.target = self
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Mac Automata", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        self.statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleAutomation(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let automation = ManifestService.shared.automation(byId: id) else { return }
        let newState = ManifestService.shared.toggleEnabled(id: id)
        if newState { _ = LaunchdService.enable(automation: automation) }
        else { LaunchdService.disable(automation: automation) }
        rebuildMenu()
    }

    @objc private func openMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController(statusBar: self)
        }
        mainWindowController?.show()
    }

    @objc private func openManageWindow() {
        if manageWindowController == nil {
            manageWindowController = ManageWindowController(statusBar: self)
        }
        manageWindowController?.show()
    }
}

import Cocoa

// Manages the menu bar icon and dropdown menu.
// Shows active automations with toggles, and provides access to the main window.
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
            button.image = NSImage(
                systemSymbolName: "gearshape.2",
                accessibilityDescription: "Mac Automata"
            )
            button.image?.size = NSSize(
                width: Styles.statusBarIconSize,
                height: Styles.statusBarIconSize
            )
        }

        rebuildMenu()
    }

    /// Rebuild the dropdown menu from current manifest state.
    func rebuildMenu() {
        let menu = NSMenu()
        let automations = ManifestService.shared.allAutomations

        // Header
        let headerItem = NSMenuItem(title: "Mac Automata", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // Status line
        let enabledCount = ManifestService.shared.enabledAutomations.count
        let total = automations.count
        let statusText: String
        if total == 0 {
            statusText = "No automations yet"
        } else {
            statusText = "\(enabledCount) of \(total) active"
        }
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        // Automation list with toggles
        if !automations.isEmpty {
            let listHeader = NSMenuItem(title: "Automations", action: nil, keyEquivalent: "")
            listHeader.isEnabled = false
            menu.addItem(listHeader)

            for automation in automations {
                let recipe = RecipeRegistry.provider(for: automation.recipeType)
                let item = NSMenuItem(
                    title: automation.displayName,
                    action: #selector(toggleAutomation(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = automation.id
                item.state = automation.isEnabled ? .on : .off

                // Show the action icon from the recipe
                if let iconName = recipe?.actionIcon,
                   let img = NSImage(systemSymbolName: iconName, accessibilityDescription: recipe?.name) {
                    let config = NSImage.SymbolConfiguration(pointSize: Styles.sidebarIconSize, weight: .regular)
                    item.image = img.withSymbolConfiguration(config)
                }

                menu.addItem(item)
            }

            menu.addItem(.separator())
        }

        // Add automation — opens the main window
        let addItem = menu.addItem(
            withTitle: "Add Automation\u{2026}",
            action: #selector(openMainWindow),
            keyEquivalent: "n"
        )
        addItem.target = self

        // Manage automations — opens the manage window
        if !automations.isEmpty {
            let manageItem = menu.addItem(
                withTitle: "Manage Automations\u{2026}",
                action: #selector(openManageWindow),
                keyEquivalent: "m"
            )
            manageItem.target = self
        }

        menu.addItem(.separator())

        // Quit
        menu.addItem(
            withTitle: "Quit Mac Automata",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        self.statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleAutomation(_ sender: NSMenuItem) {
        guard let automationId = sender.representedObject as? String else { return }
        guard let automation = ManifestService.shared.automation(byId: automationId) else { return }

        let newState = ManifestService.shared.toggleEnabled(id: automationId)

        if newState {
            _ = LaunchdService.enable(automation: automation)
        } else {
            LaunchdService.disable(automation: automation)
        }

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

    @objc private func removeAllAutomations() {
        // Confirm before removing everything
        let alert = NSAlert()
        alert.messageText = "Remove All Automations?"
        alert.informativeText = "This will unload all scheduled tasks and delete their scripts. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Uninstall each automation from launchd
            for automation in ManifestService.shared.allAutomations {
                LaunchdService.uninstall(automation: automation)
            }
            // Clear the manifest
            for automation in ManifestService.shared.allAutomations {
                ManifestService.shared.remove(id: automation.id)
            }
            rebuildMenu()
        }
    }
}

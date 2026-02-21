import Cocoa

// Manages the menu bar icon and dropdown menu.
class StatusBarController {

    private var statusItem: NSStatusItem!
    private var mainWindowController: MainWindowController?
    private var manageWindowController: ManageWindowController?
    private var aboutWindowController: AboutWindowController?

    init() {
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let automations = ManifestService.shared.allAutomations

        // Header
        let header = NSMenuItem(title: "Automata", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let manifest = ManifestService.shared.manifest
        let enabled = ManifestService.shared.enabledAutomations.count
        let total = automations.count
        let statusText: String
        if manifest.isPaused {
            statusText = "Paused"
        } else if total == 0 {
            statusText = "No automations yet"
        } else {
            statusText = "\(enabled) of \(total) active"
        }
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
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

        // Pause / Resume
        let pauseTitle = manifest.isPaused ? "Resume automations" : "Pause all automations"
        let pauseItem = menu.addItem(withTitle: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        // Disabled when: no automations, OR (not paused AND no enabled automations)
        if total == 0 || (!manifest.isPaused && enabled == 0) {
            pauseItem.isEnabled = false
        }
        menu.addItem(.separator())

        // Add + Manage
        let addItem = menu.addItem(withTitle: "New Automation\u{2026}", action: #selector(openMainWindow), keyEquivalent: "n")
        addItem.target = self

        if !automations.isEmpty {
            let manageItem = menu.addItem(withTitle: "Manage Automations\u{2026}", action: #selector(openManageWindow), keyEquivalent: "m")
            manageItem.target = self
        }

        menu.addItem(.separator())

        let aboutItem = menu.addItem(withTitle: "About Automata", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Automata", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        self.statusItem.menu = menu
        updateStatusIcon()
    }

    // MARK: - Status icon

    /// Updates the menu bar icon. Shows a green dot when automations are active (not paused).
    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let manifest = ManifestService.shared.manifest
        let hasActive = !manifest.isPaused && ManifestService.shared.enabledAutomations.count > 0

        guard let gearImage = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Automata") else { return }
        let size = NSSize(width: Styles.statusBarIconSize, height: Styles.statusBarIconSize)

        if hasActive {
            // Composite: gear + green dot
            // isTemplate must be false so the green dot keeps its color,
            // so we manually tint the gear to match the menu bar appearance.
            let composite = NSImage(size: size, flipped: false) { rect in
                // Draw the gear
                gearImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                // Tint the gear pixels to match menu bar (sourceAtop only colors existing pixels)
                let isDark = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let tint: NSColor = isDark ? .white : .black
                tint.setFill()
                rect.fill(using: .sourceAtop)
                // Draw a small green dot in the bottom-right
                let dotSize: CGFloat = 5
                let dotRect = NSRect(
                    x: rect.maxX - dotSize - 0.5,
                    y: 0.5,
                    width: dotSize, height: dotSize
                )
                NSColor.systemGreen.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
                return true
            }
            composite.isTemplate = false
            button.image = composite
        } else {
            gearImage.size = size
            gearImage.isTemplate = true
            button.image = gearImage
        }
    }

    // MARK: - Actions

    @objc private func togglePause() {
        let manifest = ManifestService.shared.manifest
        if manifest.isPaused {
            ManifestService.shared.resumeAll()
        } else {
            ManifestService.shared.pauseAll()
        }
        rebuildMenu()
    }

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

    @objc private func openAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.show()
    }
}

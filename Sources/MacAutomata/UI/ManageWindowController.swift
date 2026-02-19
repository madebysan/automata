import Cocoa

// Window for viewing and managing all automations.
// Shows each automation as a card with toggle, edit, delete, and details.
class ManageWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private weak var statusBar: StatusBarController?
    private var contentView: FlippedView?
    private var scrollView: NSScrollView?

    init(statusBar: StatusBarController) {
        self.statusBar = statusBar
        super.init()
    }

    func show() {
        NSApp.setActivationPolicy(.regular)

        if let existingWindow = window {
            rebuildList()
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 560, height: 520)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Manage Automations"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.minSize = NSSize(width: 480, height: 300)
        window = w

        // Outer container
        let outer = NSView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = outer

        // Header area
        let titleLabel = Styles.label("Automations", font: Styles.titleFont)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(titleLabel)

        let countLabel = Styles.label("", font: Styles.captionFont, color: Styles.secondaryLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.tag = 100 // Tag for easy lookup
        outer.addSubview(countLabel)

        // Add button in header
        let addButton = NSButton(title: "+ New Automation", target: self, action: #selector(addAutomation))
        addButton.bezelStyle = .rounded
        addButton.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(addButton)

        // Scroll view for automation cards
        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.drawsBackground = false
        outer.addSubview(sv)
        self.scrollView = sv

        let content = FlippedView()
        content.translatesAutoresizingMaskIntoConstraints = false
        sv.documentView = content
        self.contentView = content

        let pad = Styles.windowPadding
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: outer.topAnchor, constant: pad),
            titleLabel.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),

            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            addButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),

            sv.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: pad),
            sv.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: outer.bottomAnchor),

            content.leadingAnchor.constraint(equalTo: sv.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: sv.trailingAnchor),
            content.widthAnchor.constraint(equalTo: sv.widthAnchor),
        ])

        rebuildList()

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Build the list

    func rebuildList() {
        guard let contentView = contentView else { return }

        // Clear existing content
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let automations = ManifestService.shared.allAutomations
        let pad = Styles.windowPadding

        // Update count label
        if let outer = window?.contentView,
           let countLabel = outer.viewWithTag(100) as? NSTextField {
            let enabled = ManifestService.shared.enabledAutomations.count
            countLabel.stringValue = "\(enabled) of \(automations.count) active"
        }

        // Empty state
        if automations.isEmpty {
            let emptyIcon = NSImageView()
            if let img = NSImage(systemSymbolName: "tray", accessibilityDescription: "No automations") {
                let config = NSImage.SymbolConfiguration(pointSize: 40, weight: .light)
                emptyIcon.image = img.withSymbolConfiguration(config)
                emptyIcon.contentTintColor = Styles.tertiaryLabel
            }
            emptyIcon.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(emptyIcon)

            let emptyLabel = Styles.label("No automations yet", font: Styles.headlineFont, color: Styles.secondaryLabel)
            emptyLabel.alignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(emptyLabel)

            let emptyHint = Styles.label("Click \"+ New Automation\" to get started.", font: Styles.captionFont, color: Styles.tertiaryLabel)
            emptyHint.alignment = .center
            emptyHint.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(emptyHint)

            NSLayoutConstraint.activate([
                emptyIcon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                emptyIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 80),
                emptyLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                emptyLabel.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 12),
                emptyHint.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                emptyHint.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 4),
            ])

            let heightC = contentView.heightAnchor.constraint(equalToConstant: 250)
            heightC.priority = .defaultLow
            heightC.isActive = true
            return
        }

        // Build cards
        var yOffset: CGFloat = 0

        for automation in automations {
            let card = makeAutomationCard(automation: automation)
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)

            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            ])

            yOffset += 100
        }

        let heightC = contentView.heightAnchor.constraint(equalToConstant: yOffset + pad)
        heightC.priority = .defaultLow
        heightC.isActive = true
    }

    private func makeAutomationCard(automation: Automation) -> NSView {
        let recipe = RecipeRegistry.provider(for: automation.recipeType)

        let card = NSBox()
        card.boxType = .custom
        card.cornerRadius = Styles.cardCornerRadius
        card.fillColor = Styles.cardBackground
        card.borderColor = Styles.separator.withAlphaComponent(0.3)
        card.borderWidth = 0.5
        card.titlePosition = .noTitle
        card.contentViewMargins = .zero

        guard let inner = card.contentView else { return card }

        // Left: colored icon
        let iconView = NSImageView()
        if let iconName = recipe?.actionIcon,
           let img = NSImage(systemSymbolName: iconName, accessibilityDescription: recipe?.name) {
            let config = NSImage.SymbolConfiguration(pointSize: Styles.recipeIconSize, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = automation.isEnabled ? colorForRecipe(automation.recipeType) : Styles.tertiaryLabel
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(iconView)

        // Sentence (main label)
        let sentenceLabel = Styles.label(automation.displayName, font: Styles.headlineFont)
        sentenceLabel.translatesAutoresizingMaskIntoConstraints = false
        sentenceLabel.textColor = automation.isEnabled ? .labelColor : Styles.secondaryLabel
        inner.addSubview(sentenceLabel)

        // Status line: recipe type + last run
        let statusParts: [String] = {
            var parts = [recipe?.name ?? ""]
            if !automation.isEnabled {
                parts.append("Paused")
            } else if let lastRun = automation.lastRunAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                parts.append("Ran \(formatter.localizedString(for: lastRun, relativeTo: Date()))")
            } else {
                parts.append("Never run yet")
            }
            return parts
        }()
        let statusLabel = Styles.label(statusParts.joined(separator: "  \u{00B7}  "), font: Styles.captionFont, color: Styles.tertiaryLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(statusLabel)

        // Toggle switch
        let toggle = NSSwitch()
        toggle.state = automation.isEnabled ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleTapped(_:))
        toggle.controlSize = .small
        toggle.translatesAutoresizingMaskIntoConstraints = false
        // Store the automation ID so we can find it in the action
        objc_setAssociatedObject(toggle, "automationId", automation.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        inner.addSubview(toggle)

        // Edit button
        let editButton = NSButton(image: NSImage(systemSymbolName: "pencil", accessibilityDescription: "Edit")!, target: self, action: #selector(editTapped(_:)))
        editButton.bezelStyle = .inline
        editButton.isBordered = false
        editButton.translatesAutoresizingMaskIntoConstraints = false
        objc_setAssociatedObject(editButton, "automationId", automation.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        inner.addSubview(editButton)

        // Delete button
        let deleteButton = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!, target: self, action: #selector(deleteTapped(_:)))
        deleteButton.bezelStyle = .inline
        deleteButton.isBordered = false
        deleteButton.contentTintColor = .systemRed
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        objc_setAssociatedObject(deleteButton, "automationId", automation.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        inner.addSubview(deleteButton)

        let cardPad: CGFloat = 14

        NSLayoutConstraint.activate([
            // Icon on the left
            iconView.leadingAnchor.constraint(equalTo: inner.leadingAnchor, constant: cardPad),
            iconView.centerYAnchor.constraint(equalTo: inner.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 36),

            // Text in the middle
            sentenceLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            sentenceLabel.topAnchor.constraint(equalTo: inner.topAnchor, constant: cardPad),
            sentenceLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            statusLabel.leadingAnchor.constraint(equalTo: sentenceLabel.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: sentenceLabel.bottomAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            // Buttons row
            editButton.leadingAnchor.constraint(equalTo: sentenceLabel.leadingAnchor),
            editButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 6),
            editButton.bottomAnchor.constraint(lessThanOrEqualTo: inner.bottomAnchor, constant: -cardPad),

            deleteButton.leadingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: 8),
            deleteButton.centerYAnchor.constraint(equalTo: editButton.centerYAnchor),

            // Toggle on the right
            toggle.trailingAnchor.constraint(equalTo: inner.trailingAnchor, constant: -cardPad),
            toggle.centerYAnchor.constraint(equalTo: inner.centerYAnchor),

            // Card minimum height
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
        ])

        return card
    }

    // MARK: - Actions

    @objc private func toggleTapped(_ sender: NSSwitch) {
        guard let automationId = objc_getAssociatedObject(sender, "automationId") as? String else { return }
        guard let automation = ManifestService.shared.automation(byId: automationId) else { return }

        let newState = ManifestService.shared.toggleEnabled(id: automationId)
        if newState {
            _ = LaunchdService.enable(automation: automation)
        } else {
            LaunchdService.disable(automation: automation)
        }

        rebuildList()
        statusBar?.rebuildMenu()
    }

    @objc private func editTapped(_ sender: NSButton) {
        guard let automationId = objc_getAssociatedObject(sender, "automationId") as? String else { return }
        guard let automation = ManifestService.shared.automation(byId: automationId) else { return }
        guard let recipe = RecipeRegistry.provider(for: automation.recipeType) else { return }

        let configView = RecipeConfigView(recipe: recipe, editing: automation)

        configView.onBack = { [weak self] in
            self?.show()
        }

        configView.onSave = { [weak self] updated in
            // Uninstall old version
            LaunchdService.uninstall(automation: automation)
            // Update in manifest
            ManifestService.shared.update(updated)
            // Reinstall if enabled
            if updated.isEnabled {
                _ = LaunchdService.install(automation: updated)
            }

            self?.rebuildList()
            self?.statusBar?.rebuildMenu()

            // Switch back to the list view
            self?.show()
        }

        window?.contentView = configView
        window?.title = "Edit: \(recipe.name)"
    }

    @objc private func deleteTapped(_ sender: NSButton) {
        guard let automationId = objc_getAssociatedObject(sender, "automationId") as? String else { return }
        guard let automation = ManifestService.shared.automation(byId: automationId) else { return }

        let alert = NSAlert()
        alert.messageText = "Delete this automation?"
        alert.informativeText = automation.displayName
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            LaunchdService.uninstall(automation: automation)
            ManifestService.shared.remove(id: automationId)
            rebuildList()
            statusBar?.rebuildMenu()
        }
    }

    @objc private func addAutomation() {
        guard let statusBar = statusBar else { return }
        // Close this window and open the main add-automation flow
        window?.close()
        NSApp.setActivationPolicy(.accessory)

        // Small delay so the activation policy switch settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Trigger the "Add Automation" from the status bar
            let controller = MainWindowController(statusBar: statusBar)
            controller.show()
            // Keep reference alive
            objc_setAssociatedObject(statusBar, "addWindowController", controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private func colorForRecipe(_ type: RecipeType) -> NSColor {
        switch type {
        case .openApps, .quitApps: return Styles.appColor
        case .darkMode, .volume: return Styles.systemColor
        case .emptyTrash, .cleanDownloads: return Styles.cleanupColor
        case .openURLs: return Styles.webColor
        case .openFile, .watchAndMove: return Styles.fileColor
        case .loginLaunch: return Styles.scheduleColor
        case .onMount: return Styles.appColor
        case .intervalNotify: return Styles.audioColor
        }
    }
}

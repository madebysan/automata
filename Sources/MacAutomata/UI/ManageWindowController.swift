import Cocoa

// Window for viewing and managing all automations.
class ManageWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private weak var statusBar: StatusBarController?
    private var contentView: FlippedView?

    init(statusBar: StatusBarController) {
        self.statusBar = statusBar
        super.init()
    }

    func show() {
        NSApp.setActivationPolicy(.regular)

        if let w = window {
            rebuildList()
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 560, height: 520)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        w.title = "Manage Automations"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.minSize = NSSize(width: 480, height: 300)
        window = w

        let outer = NSView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = outer

        let titleLabel = Styles.label("Automations", font: Styles.titleFont)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(titleLabel)

        let countLabel = Styles.label("", font: Styles.captionFont, color: Styles.secondaryLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.tag = 100
        outer.addSubview(countLabel)

        let addBtn = NSButton(title: "+ New", target: self, action: #selector(addAutomation))
        addBtn.bezelStyle = .rounded
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(addBtn)

        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.hasVerticalScroller = true; sv.borderType = .noBorder; sv.drawsBackground = false
        outer.addSubview(sv)

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
            addBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            addBtn.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
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

    // MARK: - List

    func rebuildList() {
        guard let contentView = contentView else { return }
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let automations = ManifestService.shared.allAutomations
        let pad = Styles.windowPadding

        if let outer = window?.contentView, let cl = outer.viewWithTag(100) as? NSTextField {
            let e = ManifestService.shared.enabledAutomations.count
            cl.stringValue = "\(e) of \(automations.count) active"
        }

        if automations.isEmpty {
            let icon = NSImageView()
            if let img = NSImage(systemSymbolName: "tray", accessibilityDescription: "Empty") {
                icon.image = img.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 40, weight: .light))
                icon.contentTintColor = Styles.tertiaryLabel
            }
            icon.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(icon)

            let msg = Styles.label("No automations yet", font: Styles.headlineFont, color: Styles.secondaryLabel)
            msg.alignment = .center; msg.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(msg)

            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                icon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 80),
                msg.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                msg.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
            ])
            contentView.heightAnchor.constraint(equalToConstant: 250).isActive = true
            return
        }

        var y: CGFloat = 0
        for automation in automations {
            let card = makeCard(automation)
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            ])
            y += 94
        }
        let h = contentView.heightAnchor.constraint(equalToConstant: y + pad)
        h.priority = .defaultLow; h.isActive = true
    }

    private func makeCard(_ automation: Automation) -> NSView {
        let card = NSBox()
        card.boxType = .custom; card.cornerRadius = Styles.cardCornerRadius
        card.fillColor = Styles.cardBackground
        card.borderColor = Styles.separator.withAlphaComponent(0.3); card.borderWidth = 0.5
        card.titlePosition = .noTitle; card.contentViewMargins = .zero

        guard let inner = card.contentView else { return card }
        let cp: CGFloat = 14

        // Icon
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: automation.actionType.icon, accessibilityDescription: automation.actionType.name) {
            iconView.image = img.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 22, weight: .medium))
            iconView.contentTintColor = automation.isEnabled ? Styles.accentColor : Styles.tertiaryLabel
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(iconView)

        // Sentence
        let sentenceLbl = Styles.label(automation.displayName, font: Styles.headlineFont)
        sentenceLbl.textColor = automation.isEnabled ? .labelColor : Styles.secondaryLabel
        sentenceLbl.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(sentenceLbl)

        // Status line
        let triggerName = automation.triggerType.name
        let statusText = automation.isEnabled ? triggerName : "\(triggerName)  \u{00B7}  Paused"
        let statusLbl = Styles.label(statusText, font: Styles.captionFont, color: Styles.tertiaryLabel)
        statusLbl.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(statusLbl)

        // Toggle
        let toggle = NSSwitch()
        toggle.state = automation.isEnabled ? .on : .off
        toggle.target = self; toggle.action = #selector(toggleTapped(_:))
        toggle.controlSize = .small; toggle.translatesAutoresizingMaskIntoConstraints = false
        objc_setAssociatedObject(toggle, "aid", automation.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        inner.addSubview(toggle)

        // Edit + Delete
        let editBtn = NSButton(image: NSImage(systemSymbolName: "pencil", accessibilityDescription: "Edit")!, target: self, action: #selector(editTapped(_:)))
        editBtn.bezelStyle = .inline; editBtn.isBordered = false; editBtn.translatesAutoresizingMaskIntoConstraints = false
        objc_setAssociatedObject(editBtn, "aid", automation.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        inner.addSubview(editBtn)

        let delBtn = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!, target: self, action: #selector(deleteTapped(_:)))
        delBtn.bezelStyle = .inline; delBtn.isBordered = false; delBtn.contentTintColor = .systemRed; delBtn.translatesAutoresizingMaskIntoConstraints = false
        objc_setAssociatedObject(delBtn, "aid", automation.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        inner.addSubview(delBtn)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: inner.leadingAnchor, constant: cp),
            iconView.centerYAnchor.constraint(equalTo: inner.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            sentenceLbl.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            sentenceLbl.topAnchor.constraint(equalTo: inner.topAnchor, constant: cp),
            sentenceLbl.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            statusLbl.leadingAnchor.constraint(equalTo: sentenceLbl.leadingAnchor),
            statusLbl.topAnchor.constraint(equalTo: sentenceLbl.bottomAnchor, constant: 3),
            editBtn.leadingAnchor.constraint(equalTo: sentenceLbl.leadingAnchor),
            editBtn.topAnchor.constraint(equalTo: statusLbl.bottomAnchor, constant: 4),
            editBtn.bottomAnchor.constraint(lessThanOrEqualTo: inner.bottomAnchor, constant: -cp),
            delBtn.leadingAnchor.constraint(equalTo: editBtn.trailingAnchor, constant: 8),
            delBtn.centerYAnchor.constraint(equalTo: editBtn.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: inner.trailingAnchor, constant: -cp),
            toggle.centerYAnchor.constraint(equalTo: inner.centerYAnchor),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 82),
        ])
        return card
    }

    // MARK: - Actions

    @objc private func toggleTapped(_ sender: NSSwitch) {
        guard let id = objc_getAssociatedObject(sender, "aid") as? String,
              let a = ManifestService.shared.automation(byId: id) else { return }
        let newState = ManifestService.shared.toggleEnabled(id: id)
        if newState { _ = LaunchdService.enable(automation: a) }
        else { LaunchdService.disable(automation: a) }
        rebuildList(); statusBar?.rebuildMenu()
    }

    @objc private func editTapped(_ sender: NSButton) {
        guard let id = objc_getAssociatedObject(sender, "aid") as? String,
              let automation = ManifestService.shared.automation(byId: id),
              let statusBar = statusBar else { return }
        window?.close()
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let controller = MainWindowController(statusBar: statusBar)
            controller.show(editing: automation)
            objc_setAssociatedObject(statusBar, "editController", controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc private func deleteTapped(_ sender: NSButton) {
        guard let id = objc_getAssociatedObject(sender, "aid") as? String,
              let a = ManifestService.shared.automation(byId: id) else { return }
        let alert = NSAlert()
        alert.messageText = "Delete this automation?"
        alert.informativeText = a.displayName
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete"); alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            LaunchdService.uninstall(automation: a)
            ManifestService.shared.remove(id: id)
            rebuildList(); statusBar?.rebuildMenu()
        }
    }

    @objc private func addAutomation() {
        guard let statusBar = statusBar else { return }
        window?.close()
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let controller = MainWindowController(statusBar: statusBar)
            controller.show()
            objc_setAssociatedObject(statusBar, "addController", controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

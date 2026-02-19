import Cocoa
import UserNotifications

// First-run welcome screen.
// Shown once on first launch to explain the app and request permissions.
// After completing onboarding, a flag is saved so it doesn't show again.
class OnboardingWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private var permissionLabels: [String: NSTextField] = [:]

    private static let onboardingCompleteKey = "onboardingComplete"

    /// Whether onboarding has been completed before.
    static var isComplete: Bool {
        UserDefaults.standard.bool(forKey: onboardingCompleteKey)
    }

    func show() {
        NSApp.setActivationPolicy(.accessory)

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 500, height: 560)),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "Welcome to Mac Automata"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        window = w

        let outer = FlippedView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = outer

        let pad: CGFloat = 32
        var y: CGFloat = pad

        // App icon
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: "Mac Automata") {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = .controlAccentColor
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            iconView.centerXAnchor.constraint(equalTo: outer.centerXAnchor),
        ])
        y += 64

        // Welcome title
        let title = Styles.label("Welcome to Mac Automata", font: NSFont.systemFont(ofSize: 24, weight: .bold))
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(title)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            title.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            title.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 32

        // Description
        let desc = Styles.label(
            "Set up simple automations for your Mac \u{2014} no scripting needed. Pick a trigger, pick an action, and Mac Automata handles the rest.\n\nTo work properly, the app needs a few permissions:",
            font: Styles.bodyFont, color: Styles.secondaryLabel
        )
        desc.alignment = .center
        desc.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(desc)
        NSLayoutConstraint.activate([
            desc.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            desc.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            desc.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 72

        // Permission rows
        y = addPermissionRow(
            icon: "gearshape", iconColor: .systemBlue,
            title: "Automation (System Events & Finder)",
            detail: "Needed for Dark Mode toggle and Empty Trash",
            buttonTitle: "Grant Access",
            action: #selector(grantAutomation),
            statusKey: "automation",
            to: outer, at: y, padding: pad
        )
        y += 12

        y = addPermissionRow(
            icon: "bell", iconColor: .systemOrange,
            title: "Notifications",
            detail: "Needed for reminder automations",
            buttonTitle: "Allow Notifications",
            action: #selector(grantNotifications),
            statusKey: "notifications",
            to: outer, at: y, padding: pad
        )
        y += 32

        // Note about optional permissions
        let note = Styles.label(
            "These permissions are optional \u{2014} automations that don't need them will still work. You can change permissions later in System Settings > Privacy & Security.",
            font: Styles.captionFont, color: Styles.tertiaryLabel
        )
        note.alignment = .center
        note.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(note)
        NSLayoutConstraint.activate([
            note.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            note.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            note.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 40

        // Background activity warning
        let bgNote = Styles.label(
            "Heads up: macOS will show an \"App Background Activity\" notification the first time each automation is installed. This is normal \u{2014} it's how macOS tells you a new scheduled task was added. It only appears once per automation.",
            font: Styles.captionFont, color: Styles.tertiaryLabel
        )
        bgNote.alignment = .center
        bgNote.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(bgNote)
        NSLayoutConstraint.activate([
            bgNote.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            bgNote.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            bgNote.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 52

        // Get Started button
        let startButton = Styles.accentButton("Get Started", target: self, action: #selector(getStarted))
        startButton.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(startButton)
        NSLayoutConstraint.activate([
            startButton.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            startButton.centerXAnchor.constraint(equalTo: outer.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 200),
        ])

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Permission row builder

    private func addPermissionRow(
        icon: String, iconColor: NSColor,
        title: String, detail: String,
        buttonTitle: String, action: Selector,
        statusKey: String,
        to container: NSView, at yOffset: CGFloat, padding: CGFloat
    ) -> CGFloat {

        // Icon
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = iconColor
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        // Title + detail
        let titleLabel = Styles.label(title, font: Styles.headlineFont)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let detailLabel = Styles.label(detail, font: Styles.captionFont, color: Styles.secondaryLabel)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(detailLabel)

        // Status label (updates after granting)
        let statusLabel = Styles.label("", font: Styles.captionFont, color: .systemGreen)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(statusLabel)
        permissionLabels[statusKey] = statusLabel

        // Button
        let btn = NSButton(title: buttonTitle, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.controlSize = .small
        btn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(btn)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset + 4),
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            iconView.widthAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            btn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),

            statusLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 2),
            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
        ])

        return yOffset + 58
    }

    // MARK: - Permission actions

    @objc private func grantAutomation() {
        // Trigger the macOS Automation permission prompt by running a
        // harmless AppleScript targeting System Events and Finder
        PermissionService.requestAllPermissions()
        permissionLabels["automation"]?.stringValue = "Permission requested — check the prompt"
    }

    @objc private func grantNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { [weak self] in
                if granted {
                    self?.permissionLabels["notifications"]?.stringValue = "Allowed"
                } else {
                    self?.permissionLabels["notifications"]?.stringValue = "Denied — enable in System Settings"
                    self?.permissionLabels["notifications"]?.textColor = .systemOrange
                }
            }
        }
    }

    @objc private func getStarted() {
        UserDefaults.standard.set(true, forKey: OnboardingWindowController.onboardingCompleteKey)
        window?.close()
        NSApp.setActivationPolicy(.accessory)
    }
}

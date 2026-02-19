import Cocoa

// Simple About window showing app name, version, and description.
class AboutWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?

    func show() {
        NSApp.setActivationPolicy(.accessory)

        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 360, height: 280)),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "About Mac Automata"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        window = w

        let outer = FlippedView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = outer

        let pad: CGFloat = 32
        var y: CGFloat = pad

        // Icon
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: "Mac Automata") {
            let config = NSImage.SymbolConfiguration(pointSize: 40, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = .controlAccentColor
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            iconView.centerXAnchor.constraint(equalTo: outer.centerXAnchor),
        ])
        y += 56

        // App name
        let name = Styles.label("Mac Automata", font: NSFont.systemFont(ofSize: 20, weight: .bold))
        name.alignment = .center
        name.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(name)
        NSLayoutConstraint.activate([
            name.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            name.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            name.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 28

        // Version
        let version = Styles.label("Version 0.2.0", font: Styles.captionFont, color: Styles.secondaryLabel)
        version.alignment = .center
        version.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(version)
        NSLayoutConstraint.activate([
            version.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            version.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            version.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 24

        // Description
        let desc = Styles.label(
            "Simple automations for your Mac.\nNo scripting, no flowcharts \u{2014} just pick a trigger and an action.",
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
        y += 52

        // Credit
        let credit = Styles.label("Made by san", font: Styles.captionFont, color: Styles.tertiaryLabel)
        credit.alignment = .center
        credit.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(credit)
        NSLayoutConstraint.activate([
            credit.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            credit.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            credit.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

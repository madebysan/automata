import Cocoa

// Browse view showing pre-built automation templates grouped by category.
// Each template card has an icon, name, subtitle, and a "+" button to add it.
// Templates that need user input open the builder pre-filled.
// Templates that are fully configured install immediately.
class TemplatesView: NSView {

    /// Called when a template is selected. The automation is ready to save
    /// (if needsInput is false) or the builder should open (if true).
    var onTemplateSelected: ((Template) -> Void)?

    /// Called when user taps "Custom Automation" to open a blank builder.
    var onCustom: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        addSubview(scroll)

        let content = FlippedView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = content

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        let pad = Styles.windowPadding
        var y: CGFloat = pad

        // Title
        let title = Styles.label("New Automation", font: Styles.titleFont)
        title.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(title)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: y),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
        ])
        y += 32

        let subtitle = Styles.label("Pick a template or build your own.", font: Styles.captionFont, color: Styles.secondaryLabel)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(subtitle)
        NSLayoutConstraint.activate([
            subtitle.topAnchor.constraint(equalTo: content.topAnchor, constant: y),
            subtitle.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
        ])
        y += 28

        // Custom button at the top
        let customBtn = NSButton(title: "Build Custom Automation\u{2026}", target: self, action: #selector(customTapped))
        customBtn.bezelStyle = .rounded
        customBtn.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(customBtn)
        NSLayoutConstraint.activate([
            customBtn.topAnchor.constraint(equalTo: content.topAnchor, constant: y),
            customBtn.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
        ])
        y += 40

        // Template groups
        for group in TemplateLibrary.grouped {
            // Category header
            let header = Styles.sectionHeader(group.category.rawValue)
            header.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(header)
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: content.topAnchor, constant: y),
                header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            ])
            y += 22

            // Template cards
            for template in group.templates {
                let card = makeTemplateCard(template)
                card.translatesAutoresizingMaskIntoConstraints = false
                content.addSubview(card)
                NSLayoutConstraint.activate([
                    card.topAnchor.constraint(equalTo: content.topAnchor, constant: y),
                    card.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
                    card.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
                    card.heightAnchor.constraint(equalToConstant: 52),
                ])
                y += 56
            }

            y += 8 // Extra spacing between categories
        }

        y += pad
        let h = content.heightAnchor.constraint(equalToConstant: y)
        h.priority = .defaultLow
        h.isActive = true
    }

    private func makeTemplateCard(_ template: Template) -> NSView {
        // Clickable card
        let card = NSButton()
        card.bezelStyle = .roundRect
        card.isBordered = false
        card.title = ""
        card.wantsLayer = true
        card.layer?.cornerRadius = 8

        // Icon with colored background circle
        let iconBg = NSView()
        iconBg.wantsLayer = true
        iconBg.layer?.cornerRadius = 16
        iconBg.layer?.backgroundColor = template.color.withAlphaComponent(0.15).cgColor
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconBg)

        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: template.icon, accessibilityDescription: template.name) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = template.color
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // Name
        let nameLabel = Styles.label(template.name, font: Styles.headlineFont)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)

        // Subtitle
        let subLabel = Styles.label(template.subtitle, font: Styles.captionFont, color: Styles.secondaryLabel)
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(subLabel)

        // Plus button
        let plusBtn = NSButton(image: NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: "Add")!, target: self, action: #selector(templateTapped(_:)))
        plusBtn.bezelStyle = .inline
        plusBtn.isBordered = false
        plusBtn.contentTintColor = Styles.accentColor
        plusBtn.translatesAutoresizingMaskIntoConstraints = false
        let idx = TemplateLibrary.all.firstIndex(where: { $0.id == template.id }) ?? 0
        plusBtn.tag = idx
        card.addSubview(plusBtn)

        // Also make the whole card clickable
        card.target = self
        card.action = #selector(templateTapped(_:))
        card.tag = idx

        NSLayoutConstraint.activate([
            iconBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            iconBg.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 32),
            iconBg.heightAnchor.constraint(equalToConstant: 32),
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: plusBtn.leadingAnchor, constant: -8),

            subLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            subLabel.trailingAnchor.constraint(lessThanOrEqualTo: plusBtn.leadingAnchor, constant: -8),

            plusBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            plusBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            plusBtn.widthAnchor.constraint(equalToConstant: 24),
            plusBtn.heightAnchor.constraint(equalToConstant: 24),
        ])

        return card
    }

    // MARK: - Actions

    @objc private func templateTapped(_ sender: NSControl) {
        let idx = sender.tag
        guard idx >= 0 && idx < TemplateLibrary.all.count else { return }
        onTemplateSelected?(TemplateLibrary.all[idx])
    }

    @objc private func customTapped() {
        onCustom?()
    }
}

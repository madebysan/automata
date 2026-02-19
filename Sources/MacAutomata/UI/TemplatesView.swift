import Cocoa

// Browse view showing pre-built automation templates grouped by category.
// Each category shows 2 templates by default with a "Show more" toggle.
class TemplatesView: NSView {

    var onTemplateSelected: ((Template) -> Void)?
    var onCustom: (() -> Void)?

    // Track which categories are expanded
    private var expandedCategories: Set<String> = []
    private var scrollView: NSScrollView!
    private var contentView: FlippedView!
    private let previewCount = 2 // Templates visible before "Show more"

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        addSubview(scrollView)

        contentView = FlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        rebuildContent()
    }

    private func rebuildContent() {
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let pad = Styles.windowPadding
        var y: CGFloat = pad

        // Title
        let title = Styles.label("New Automation", font: Styles.titleFont)
        title.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(title)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
        ])
        y += 32

        let subtitle = Styles.label("Pick a template or build your own.", font: Styles.captionFont, color: Styles.secondaryLabel)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitle)
        NSLayoutConstraint.activate([
            subtitle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            subtitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
        ])
        y += 28

        // Custom button
        let customBtn = NSButton(title: "Build Custom Automation\u{2026}", target: self, action: #selector(customTapped))
        customBtn.bezelStyle = .rounded
        customBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(customBtn)
        NSLayoutConstraint.activate([
            customBtn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            customBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
        ])
        y += 44

        // Template groups with collapsible sections
        for group in TemplateLibrary.grouped {
            let catKey = group.category.rawValue
            let isExpanded = expandedCategories.contains(catKey)
            let templates = group.templates
            let visibleTemplates = isExpanded ? templates : Array(templates.prefix(previewCount))
            let hiddenCount = templates.count - previewCount

            // Category header
            let header = Styles.sectionHeader(catKey)
            header.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(header)
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                header.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            ])
            y += 22

            // Visible template cards
            for template in visibleTemplates {
                let card = makeTemplateCard(template)
                card.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(card)
                NSLayoutConstraint.activate([
                    card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                    card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
                    card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
                    card.heightAnchor.constraint(equalToConstant: 52),
                ])
                y += 56
            }

            // "Show more" / "Show less" button
            if hiddenCount > 0 {
                let toggleTitle = isExpanded
                    ? "Show less"
                    : "Show \(hiddenCount) more\u{2026}"
                let toggleBtn = NSButton(title: toggleTitle, target: self, action: #selector(toggleSection(_:)))
                toggleBtn.bezelStyle = .inline
                toggleBtn.font = Styles.captionFont
                toggleBtn.contentTintColor = Styles.accentColor
                toggleBtn.translatesAutoresizingMaskIntoConstraints = false
                objc_setAssociatedObject(toggleBtn, "catKey", catKey, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                contentView.addSubview(toggleBtn)
                NSLayoutConstraint.activate([
                    toggleBtn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                    toggleBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad + 42),
                ])
                y += 24
            }

            y += 12
        }

        y += pad
        let h = contentView.heightAnchor.constraint(equalToConstant: y)
        h.priority = .defaultLow
        h.isActive = true
    }

    private func makeTemplateCard(_ template: Template) -> NSView {
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

        let nameLabel = Styles.label(template.name, font: Styles.headlineFont)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)

        let subLabel = Styles.label(template.subtitle, font: Styles.captionFont, color: Styles.secondaryLabel)
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(subLabel)

        let plusBtn = NSButton(image: NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: "Add")!, target: self, action: #selector(templateTapped(_:)))
        plusBtn.bezelStyle = .inline
        plusBtn.isBordered = false
        plusBtn.contentTintColor = Styles.accentColor
        plusBtn.translatesAutoresizingMaskIntoConstraints = false
        let idx = TemplateLibrary.all.firstIndex(where: { $0.id == template.id }) ?? 0
        plusBtn.tag = idx
        card.addSubview(plusBtn)

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

    @objc private func toggleSection(_ sender: NSButton) {
        guard let catKey = objc_getAssociatedObject(sender, "catKey") as? String else { return }
        if expandedCategories.contains(catKey) {
            expandedCategories.remove(catKey)
        } else {
            expandedCategories.insert(catKey)
        }
        rebuildContent()
    }

    @objc private func customTapped() {
        onCustom?()
    }
}

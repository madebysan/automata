import Cocoa

// Browse view showing pre-built automation templates grouped by category.
// Includes a natural language text field at the top for describing automations
// in plain English, which uses NLParser to suggest the right setup.
class TemplatesView: NSView, NSTextFieldDelegate {

    var onTemplateSelected: ((Template) -> Void)?
    var onSuggestionSelected: ((NLParser.Suggestion) -> Void)?
    var onCustom: (() -> Void)?

    // Track which categories are expanded
    private var expandedCategories: Set<String> = []
    private var scrollView: NSScrollView!
    private var contentView: FlippedView!
    private let previewCount = 4 // Templates visible before "Show more" (2 rows of 2)

    // NL input state
    private var searchField: NSTextField!
    private var currentParseResult: NLParser.ParseResult?

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

        // Title row: title on the left, Custom button on the right (same baseline)
        let title = Styles.label("New Automation", font: Styles.titleFont)
        title.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(title)

        let customBtn = Styles.accentButton("Custom Automation\u{2026}", target: self, action: #selector(customTapped))
        customBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(customBtn)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            title.trailingAnchor.constraint(lessThanOrEqualTo: customBtn.leadingAnchor, constant: -12),
            customBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            customBtn.centerYAnchor.constraint(equalTo: title.centerYAnchor),
        ])
        y += 38

        let subtitle = Styles.label("Describe what you want, or pick a template below.", font: Styles.captionFont, color: Styles.secondaryLabel)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitle)
        NSLayoutConstraint.activate([
            subtitle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            subtitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
        ])
        y += 28

        // Natural language search field
        searchField = NSTextField()
        searchField.placeholderString = "Describe your automation\u{2026} e.g., \u{201c}dark mode at 10pm\u{201d}"
        searchField.font = Styles.bodyFont
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        searchField.focusRingType = .exterior
        searchField.bezelStyle = .roundedBezel
        // Text field contents are restored after rebuildContent() by callers
        contentView.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            searchField.heightAnchor.constraint(equalToConstant: 28),
        ])
        y += 40

        // Show suggestion area if we have a parse result
        if let result = currentParseResult {
            y = renderSuggestions(result, startY: y, pad: pad)
        }

        // Two-column layout: categories flow vertically within each column.
        // Left column: first 3 categories. Right column: the rest.
        // This ensures both columns always start with a category header — no orphans.
        let grouped = TemplateLibrary.grouped
        let colGap: CGFloat = 24
        let splitIndex = min(3, grouped.count)
        let leftGroups  = Array(grouped.prefix(splitIndex))
        let rightGroups = Array(grouped.dropFirst(splitIndex))

        let columnsStartY = y
        var leftY  = columnsStartY
        var rightY = columnsStartY

        for group in leftGroups {
            guard let gi = grouped.firstIndex(where: { $0.category == group.category }) else { continue }
            leftY = renderCategoryColumn(group, globalIndex: gi, topY: leftY, isLeft: true, colGap: colGap, pad: pad)
        }
        for group in rightGroups {
            guard let gi = grouped.firstIndex(where: { $0.category == group.category }) else { continue }
            rightY = renderCategoryColumn(group, globalIndex: gi, topY: rightY, isLeft: false, colGap: colGap, pad: pad)
        }

        y = max(leftY, rightY) + pad
        let h = contentView.heightAnchor.constraint(equalToConstant: y)
        h.priority = .defaultLow
        h.isActive = true
    }

    // MARK: - Suggestion rendering

    /// Render the suggestion area and return the updated y position.
    private func renderSuggestions(_ result: NLParser.ParseResult, startY: CGFloat, pad: CGFloat) -> CGFloat {
        var y = startY
        let suggestions = result.suggestions
        let templates = result.matchedTemplates

        if suggestions.isEmpty && templates.isEmpty {
            // No match at all
            y = renderNoMatch(startY: y, pad: pad)
        } else if let top = suggestions.first, top.score >= 0.5 {
            // High confidence: show best match + alternatives
            y = renderHighConfidence(suggestions, startY: y, pad: pad)
        } else {
            // Low confidence: show alternatives + related templates
            y = renderLowConfidence(suggestions, templates: templates, startY: y, pad: pad)
        }

        y += 8 // gap before template grid
        return y
    }

    private func renderHighConfidence(_ suggestions: [NLParser.Suggestion], startY: CGFloat, pad: CGFloat) -> CGFloat {
        var y = startY

        // "Best match" label
        let header = Styles.label("Best match", font: Styles.smallBoldFont, color: .systemGreen)
        header.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            header.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
        ])
        y += 20

        // Top suggestion card
        if let top = suggestions.first {
            let card = makeSuggestionCard(top, index: 0)
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
                card.heightAnchor.constraint(equalToConstant: 52),
            ])
            y += 60
        }

        // Alternatives
        let alts = Array(suggestions.dropFirst())
        if !alts.isEmpty {
            let altLabel = Styles.label("Also possible:", font: Styles.captionFont, color: Styles.secondaryLabel)
            altLabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(altLabel)
            NSLayoutConstraint.activate([
                altLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                altLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            ])
            y += 20

            for (i, alt) in alts.enumerated() {
                let card = makeSuggestionCard(alt, index: i + 1)
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
        }

        return y
    }

    private func renderLowConfidence(_ suggestions: [NLParser.Suggestion], templates: [Template], startY: CGFloat, pad: CGFloat) -> CGFloat {
        var y = startY

        let header = Styles.label("Hmm, I\u{2019}m not sure about that. Did you mean:", font: Styles.captionFont, color: Styles.secondaryLabel)
        header.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            header.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            header.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
        ])
        y += 22

        // Show suggestions if any
        for (i, suggestion) in suggestions.prefix(2).enumerated() {
            let card = makeSuggestionCard(suggestion, index: i)
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

        // Show matched templates
        for template in templates.prefix(2) {
            let card = makeTemplateCard(template)
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
                card.heightAnchor.constraint(equalToConstant: 68),
            ])
            y += 72
        }

        // Hint examples
        y = renderExampleHints(startY: y, pad: pad)

        return y
    }

    private func renderNoMatch(startY: CGFloat, pad: CGFloat) -> CGFloat {
        var y = startY

        let header = Styles.label("I couldn\u{2019}t match that to an automation.", font: Styles.captionFont, color: Styles.secondaryLabel)
        header.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            header.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            header.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
        ])
        y += 20

        y = renderExampleHints(startY: y, pad: pad)

        let pickLabel = Styles.label("Or pick a template below.", font: Styles.captionFont, color: Styles.secondaryLabel)
        pickLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pickLabel)
        NSLayoutConstraint.activate([
            pickLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            pickLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
        ])
        y += 20

        return y
    }

    private func renderExampleHints(startY: CGFloat, pad: CGFloat) -> CGFloat {
        var y = startY

        let hintHeader = Styles.label("Try something like:", font: Styles.captionFont, color: Styles.secondaryLabel)
        hintHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hintHeader)
        NSLayoutConstraint.activate([
            hintHeader.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
            hintHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
        ])
        y += 18

        let examples = [
            "\u{2022} \u{201c}Open Slack and Figma at 9am weekdays\u{201d}",
            "\u{2022} \u{201c}Empty trash every Friday at 5pm\u{201d}",
            "\u{2022} \u{201c}Remind me to stretch every 30 minutes\u{201d}",
        ]
        for example in examples {
            let label = Styles.label(example, font: Styles.captionFont, color: Styles.tertiaryLabel)
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad + 8),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            ])
            y += 16
        }

        return y
    }

    // MARK: - Suggestion card

    /// Store suggestions for button tag lookup
    private var activeSuggestions: [NLParser.Suggestion] = []

    private func makeSuggestionCard(_ suggestion: NLParser.Suggestion, index: Int) -> NSView {
        // Track suggestions for tap handling
        if index >= activeSuggestions.count {
            activeSuggestions.append(suggestion)
        } else {
            activeSuggestions[index] = suggestion
        }

        let card = HoverCardButton()
        card.bezelStyle = .roundRect
        card.isBordered = false
        card.title = ""
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.target = self
        card.action = #selector(suggestionTapped(_:))
        card.tag = 2000 + index

        // Action icon with colored circle
        let actionIcon = suggestion.actionType.icon
        let iconColor = iconColorForAction(suggestion.actionType)

        let iconBg = NSView()
        iconBg.wantsLayer = true
        iconBg.layer?.cornerRadius = 14
        iconBg.layer?.backgroundColor = iconColor.withAlphaComponent(0.15).cgColor
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconBg)

        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: actionIcon, accessibilityDescription: suggestion.actionType.name) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = iconColor
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // Summary text
        let summaryLabel = Styles.label(suggestion.summary, font: Styles.headlineFont)
        summaryLabel.maximumNumberOfLines = 1
        summaryLabel.cell?.lineBreakMode = .byTruncatingTail
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(summaryLabel)

        // Missing fields hint
        let missingText: String
        if suggestion.missingFields.isEmpty {
            missingText = "Ready to configure"
        } else {
            missingText = "Needs: \(suggestion.missingFields.joined(separator: ", "))"
        }
        let missingLabel = Styles.label(missingText, font: Styles.captionFont, color: Styles.secondaryLabel)
        missingLabel.maximumNumberOfLines = 1
        missingLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(missingLabel)

        // Arrow indicator
        let arrowView = NSImageView()
        if let img = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Use this") {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            arrowView.image = img.withSymbolConfiguration(config)
            arrowView.contentTintColor = Styles.tertiaryLabel
        }
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(arrowView)

        NSLayoutConstraint.activate([
            iconBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            iconBg.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 30),
            iconBg.heightAnchor.constraint(equalToConstant: 30),
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            summaryLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),
            summaryLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 9),
            summaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrowView.leadingAnchor, constant: -8),

            missingLabel.leadingAnchor.constraint(equalTo: summaryLabel.leadingAnchor),
            missingLabel.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 1),
            missingLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrowView.leadingAnchor, constant: -8),

            arrowView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            arrowView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: 14),
            arrowView.heightAnchor.constraint(equalToConstant: 14),
        ])

        return card
    }

    /// Map action types to display colors for suggestion cards.
    private func iconColorForAction(_ action: ActionType) -> NSColor {
        switch action {
        case .darkMode: return .systemIndigo
        case .setVolume: return .systemPink
        case .emptyTrash, .cleanDownloads: return .systemTeal
        case .openApps, .quitApps: return .systemOrange
        case .showNotification: return .systemGreen
        case .moveFiles: return .systemYellow
        case .openURLs: return .systemIndigo
        case .openFile: return .systemYellow
        case .keepAwake: return .systemOrange
        }
    }

    // MARK: - Category rendering

    /// Render one category group into either the left or right column.
    /// Returns the updated y after all items in this category are placed.
    @discardableResult
    private func renderCategoryColumn(
        _ group: (category: TemplateCategory, templates: [Template]),
        globalIndex: Int,
        topY: CGFloat,
        isLeft: Bool,
        colGap: CGFloat,
        pad: CGFloat
    ) -> CGFloat {
        var y = topY
        let catKey = group.category.rawValue
        let isExpanded = expandedCategories.contains(catKey)
        let visibleTemplates = isExpanded ? group.templates : Array(group.templates.prefix(previewCount))
        let hiddenCount = group.templates.count - previewCount
        let cardHeight: CGFloat = 68

        // Category header
        let header = Styles.sectionHeader(catKey)
        header.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(header)
        if isLeft {
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                header.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
                header.trailingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -(colGap / 2)),
            ])
        } else {
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                header.leadingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: colGap / 2),
                header.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            ])
        }
        y += 26

        // Cards stacked vertically within the category
        for (i, template) in visibleTemplates.enumerated() {
            let card = makeTemplateCard(template)
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)
            if isLeft {
                NSLayoutConstraint.activate([
                    card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                    card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
                    card.trailingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -(colGap / 2)),
                    card.heightAnchor.constraint(equalToConstant: cardHeight),
                ])
            } else {
                NSLayoutConstraint.activate([
                    card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                    card.leadingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: colGap / 2),
                    card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
                    card.heightAnchor.constraint(equalToConstant: cardHeight),
                ])
            }
            let isLast = i == visibleTemplates.count - 1
            y += cardHeight + (isLast ? 0 : 8)
        }

        // "Show more / less" button
        if hiddenCount > 0 {
            y += 6
            let toggleTitle = isExpanded ? "Show less" : "Show \(hiddenCount) more\u{2026}"
            let toggleBtn = NSButton(title: toggleTitle, target: self, action: #selector(toggleSection(_:)))
            toggleBtn.bezelStyle = .inline
            toggleBtn.font = Styles.captionFont
            toggleBtn.contentTintColor = Styles.accentColor
            toggleBtn.translatesAutoresizingMaskIntoConstraints = false
            toggleBtn.tag = 1000 + globalIndex
            contentView.addSubview(toggleBtn)
            if isLeft {
                NSLayoutConstraint.activate([
                    toggleBtn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                    toggleBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
                ])
            } else {
                NSLayoutConstraint.activate([
                    toggleBtn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: y),
                    toggleBtn.leadingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: colGap / 2),
                ])
            }
            y += 24
        }

        y += 20  // gap before next category header
        return y
    }

    private func makeTemplateCard(_ template: Template) -> NSView {
        let card = HoverCardButton()
        card.bezelStyle = .roundRect
        card.isBordered = false
        card.title = ""
        card.wantsLayer = true
        card.layer?.cornerRadius = 10

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
        nameLabel.maximumNumberOfLines = 1
        nameLabel.cell?.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)

        let subLabel = Styles.label(template.subtitle, font: Styles.captionFont, color: Styles.secondaryLabel)
        subLabel.maximumNumberOfLines = 1
        subLabel.cell?.lineBreakMode = .byTruncatingTail
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(subLabel)

        let plusImg = NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: "Add")!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 20, weight: .regular))!
        let plusBtn = NSButton(image: plusImg, target: self, action: #selector(templateTapped(_:)))
        plusBtn.bezelStyle = .inline
        plusBtn.isBordered = false
        plusBtn.contentTintColor = NSColor.tertiaryLabelColor
        plusBtn.translatesAutoresizingMaskIntoConstraints = false
        let idx = TemplateLibrary.all.firstIndex(where: { $0.id == template.id }) ?? 0
        plusBtn.tag = idx
        card.addSubview(plusBtn)

        card.target = self
        card.action = #selector(templateTapped(_:))
        card.tag = idx

        NSLayoutConstraint.activate([
            iconBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            iconBg.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 36),
            iconBg.heightAnchor.constraint(equalToConstant: 36),
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: plusBtn.leadingAnchor, constant: -8),

            subLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            subLabel.trailingAnchor.constraint(lessThanOrEqualTo: plusBtn.leadingAnchor, constant: -8),

            plusBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            plusBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            plusBtn.widthAnchor.constraint(equalToConstant: 28),
            plusBtn.heightAnchor.constraint(equalToConstant: 28),
        ])

        return card
    }

    // MARK: - Actions

    @objc private func templateTapped(_ sender: NSControl) {
        let idx = sender.tag
        guard idx >= 0 && idx < TemplateLibrary.all.count else { return }
        onTemplateSelected?(TemplateLibrary.all[idx])
    }

    @objc private func suggestionTapped(_ sender: NSControl) {
        let idx = sender.tag - 2000
        guard idx >= 0 && idx < activeSuggestions.count else { return }
        onSuggestionSelected?(activeSuggestions[idx])
    }

    @objc private func toggleSection(_ sender: NSButton) {
        let groupIndex = sender.tag - 1000
        let grouped = TemplateLibrary.grouped
        guard groupIndex >= 0 && groupIndex < grouped.count else { return }
        let catKey = grouped[groupIndex].category.rawValue
        if expandedCategories.contains(catKey) {
            expandedCategories.remove(catKey)
        } else {
            expandedCategories.insert(catKey)
        }
        let savedText = searchField?.stringValue ?? ""
        rebuildContent()
        searchField?.stringValue = savedText
    }

    @objc private func customTapped() {
        onCustom?()
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            // Return key pressed — parse the input
            let text = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            activeSuggestions = []
            if text.isEmpty {
                currentParseResult = nil
            } else {
                currentParseResult = NLParser.parse(text)
            }
            let savedText = searchField.stringValue
            rebuildContent()
            searchField.stringValue = savedText
            // Re-focus the search field
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(self.searchField)
            }
            return true
        }
        if commandSelector == #selector(cancelOperation(_:)) {
            // Escape key — clear suggestions
            searchField.stringValue = ""
            activeSuggestions = []
            currentParseResult = nil
            rebuildContent()
            return true
        }
        return false
    }
}

// NSButton subclass that brightens its background slightly on mouse hover.
// Uses updateLayer so the background color resolves correctly in the current
// appearance context — avoids vibrancy causing inconsistent card colors.
private class HoverCardButton: NSButton {

    var isHovered = false

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        let base = NSColor.controlBackgroundColor
        if isHovered {
            layer?.backgroundColor = (base.blended(withFraction: 0.06, of: .labelColor) ?? base).cgColor
        } else {
            layer?.backgroundColor = base.cgColor
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self, userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }
}

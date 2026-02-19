import Cocoa

// Step 1 of the setup flow: pick which recipe to configure.
// Shows a grid/list of recipe cards, each with icon + name + description.
// IFTTT-inspired: template-first, users pick from pre-built options.
class RecipePickerView: NSView {

    /// Called when the user picks a recipe.
    var onRecipePicked: ((RecipeProvider) -> Void)?

    private let scrollView = NSScrollView()
    private let contentView = FlippedView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Title
        let title = Styles.label("Choose a Recipe", font: Styles.titleFont)
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        let subtitle = Styles.label(
            "Pick what you want to automate, then configure the details.",
            font: Styles.captionFont,
            color: Styles.secondaryLabel
        )
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitle)

        // Scrollable list of recipe cards
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: Styles.windowPadding),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Styles.windowPadding),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Styles.windowPadding),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Styles.windowPadding),
            subtitle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Styles.windowPadding),

            scrollView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: Styles.sectionSpacing),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        buildRecipeCards()
    }

    private func buildRecipeCards() {
        var yOffset: CGFloat = 0
        let padding = Styles.windowPadding

        for recipe in RecipeRegistry.all {
            let card = makeRecipeCard(recipe: recipe)
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)

            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
                card.heightAnchor.constraint(equalToConstant: 64),
            ])

            yOffset += 64 + Styles.itemSpacing
        }

        // Set content height so scrolling works
        let heightConstraint = contentView.heightAnchor.constraint(equalToConstant: yOffset)
        heightConstraint.priority = .defaultLow
        heightConstraint.isActive = true
    }

    private func makeRecipeCard(recipe: RecipeProvider) -> NSView {
        let card = NSButton()
        card.bezelStyle = .roundRect
        card.isBordered = false
        card.title = ""
        card.target = self
        card.action = #selector(cardClicked(_:))
        card.tag = RecipeRegistry.all.firstIndex(where: { $0.type == recipe.type }) ?? 0

        // Hover effect via tracking area
        card.wantsLayer = true
        card.layer?.cornerRadius = Styles.cardCornerRadius

        // Build the card content
        let icon = NSImageView()
        if let img = NSImage(systemSymbolName: recipe.actionIcon, accessibilityDescription: recipe.name) {
            let config = NSImage.SymbolConfiguration(pointSize: Styles.recipeIconSize, weight: .medium)
            icon.image = img.withSymbolConfiguration(config)
            icon.contentTintColor = colorForRecipe(recipe)
        }
        icon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = Styles.label(recipe.name, font: Styles.headlineFont)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = Styles.label(recipe.description, font: Styles.captionFont, color: Styles.secondaryLabel)
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        let arrow = NSImageView()
        if let img = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Configure") {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            arrow.image = img.withSymbolConfiguration(config)
            arrow.contentTintColor = Styles.tertiaryLabel
        }
        arrow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(nameLabel)
        card.addSubview(descLabel)
        card.addSubview(arrow)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 36),

            nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrow.leadingAnchor, constant: -8),

            descLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrow.leadingAnchor, constant: -8),

            arrow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            arrow.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 12),
        ])

        return card
    }

    @objc private func cardClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0 && index < RecipeRegistry.all.count else { return }
        let recipe = RecipeRegistry.all[index]
        onRecipePicked?(recipe)
    }

    /// Map recipe types to category colors.
    private func colorForRecipe(_ recipe: RecipeProvider) -> NSColor {
        switch recipe.type {
        case .openApps, .quitApps: return Styles.appColor
        case .darkMode, .volume: return Styles.systemColor
        case .emptyTrash, .cleanDownloads: return Styles.cleanupColor
        case .openURLs: return Styles.webColor
        }
    }
}

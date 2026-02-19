import Cocoa

// Step 2 of the setup flow: configure the selected recipe's parameters.
// Dynamically builds form fields from the recipe's field definitions.
// Shows a preview sentence at the bottom (IFTTT-inspired).
class RecipeConfigView: NSView {

    /// Called when user saves the configured automation.
    var onSave: ((Automation) -> Void)?
    /// Called when user taps Back.
    var onBack: (() -> Void)?

    private let recipe: RecipeProvider
    private var fieldValues: [String: String] = [:]
    private var sentenceLabel: NSTextField!
    private var errorLabel: NSTextField!

    // References to dynamic controls for reading values
    private var hourPicker: NSPopUpButton?
    private var minutePicker: NSPopUpButton?
    private var weekdayButtons: [NSButton] = []
    private var appTokenField: NSTextField?
    private var urlTextView: NSTextView?
    private var numberField: NSTextField?
    private var dropdownPopup: NSPopUpButton?
    private var dropdownKey: String?

    init(recipe: RecipeProvider) {
        self.recipe = recipe
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(recipe:)")
    }

    private func setup() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        addSubview(scrollView)

        let contentView = FlippedView()
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

        let pad = Styles.windowPadding
        var yOffset: CGFloat = pad

        // Back button
        let backButton = NSButton(title: "\u{2190} Back", target: self, action: #selector(backTapped))
        backButton.bezelStyle = .inline
        backButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
        ])
        yOffset += 30

        // Title
        let title = Styles.label("Configure: \(recipe.name)", font: Styles.titleFont)
        title.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(title)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
        ])
        yOffset += 40

        // Build fields dynamically
        for field in recipe.fields {
            yOffset = addField(field, to: contentView, at: yOffset, padding: pad)
            yOffset += Styles.sectionSpacing
        }

        // Error label (hidden by default)
        errorLabel = Styles.label("", font: Styles.captionFont, color: .systemRed)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.isHidden = true
        contentView.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            errorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            errorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
        ])
        yOffset += 20

        // Preview sentence (IFTTT-inspired)
        let previewHeader = Styles.sectionHeader("Preview")
        previewHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previewHeader)
        NSLayoutConstraint.activate([
            previewHeader.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            previewHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
        ])
        yOffset += 20

        sentenceLabel = Styles.label("Fill in the fields above to see a preview.", font: Styles.sentenceFont, color: Styles.secondaryLabel)
        sentenceLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sentenceLabel)
        NSLayoutConstraint.activate([
            sentenceLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            sentenceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            sentenceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
        ])
        yOffset += 40

        // Save button
        let saveButton = Styles.accentButton("Save Automation", target: self, action: #selector(saveTapped))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(saveButton)
        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            saveButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 200),
        ])
        yOffset += 60

        // Set content height
        let heightConstraint = contentView.heightAnchor.constraint(equalToConstant: yOffset)
        heightConstraint.priority = .defaultLow
        heightConstraint.isActive = true
    }

    // MARK: - Field builders

    private func addField(_ field: RecipeField, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        switch field {
        case .timePicker(let label):
            return addTimePicker(label: label, to: container, at: yOffset, padding: padding)
        case .weekdayPicker(let label):
            return addWeekdayPicker(label: label, to: container, at: yOffset, padding: padding)
        case .appPicker(let label, _):
            return addAppPicker(label: label, to: container, at: yOffset, padding: padding)
        case .numberField(let label, let placeholder, let unit):
            return addNumberField(label: label, placeholder: placeholder, unit: unit, to: container, at: yOffset, padding: padding)
        case .urlList(let label):
            return addURLList(label: label, to: container, at: yOffset, padding: padding)
        case .dropdown(let label, let key, let options):
            return addDropdown(label: label, key: key, options: options, to: container, at: yOffset, padding: padding)
        case .toggle:
            return yOffset // Not used in v0 recipes
        }
    }

    private func addTimePicker(label: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let hourPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        hourPopup.removeAllItems()
        for h in 0..<24 {
            let period = h >= 12 ? "PM" : "AM"
            let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            hourPopup.addItem(withTitle: "\(display) \(period)")
            hourPopup.lastItem?.tag = h
        }
        hourPopup.selectItem(at: 9) // Default to 9 AM
        hourPopup.target = self
        hourPopup.action = #selector(fieldChanged)
        hourPopup.translatesAutoresizingMaskIntoConstraints = false
        self.hourPicker = hourPopup

        let minutePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        minutePopup.removeAllItems()
        for m in stride(from: 0, to: 60, by: 5) {
            minutePopup.addItem(withTitle: String(format: ":%02d", m))
            minutePopup.lastItem?.tag = m
        }
        minutePopup.target = self
        minutePopup.action = #selector(fieldChanged)
        minutePopup.translatesAutoresizingMaskIntoConstraints = false
        self.minutePicker = minutePopup

        let row = NSStackView(views: [hourPopup, minutePopup])
        row.orientation = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            row.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
        ])

        // Set default values
        fieldValues["hour"] = "9"
        fieldValues["minute"] = "0"

        return yOffset + 50
    }

    private func addWeekdayPicker(label: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        weekdayButtons = []

        var buttons: [NSView] = []
        for (i, name) in dayNames.enumerated() {
            let btn = NSButton(checkboxWithTitle: name, target: self, action: #selector(weekdayChanged))
            btn.tag = i + 1 // launchd uses 1-7 (1=Sunday)
            btn.font = Styles.captionFont
            // Default: weekdays selected
            if i >= 1 && i <= 5 { btn.state = .on }
            weekdayButtons.append(btn)
            buttons.append(btn)
        }

        let row = NSStackView(views: buttons)
        row.orientation = .horizontal
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            row.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
        ])

        // Set default weekday values
        fieldValues["weekdays"] = "2,3,4,5,6"

        return yOffset + 50
    }

    private func addAppPicker(label: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let hint = Styles.label("Comma-separated app names (e.g., Safari, Xcode, Figma)", font: Styles.captionFont, color: Styles.tertiaryLabel)
        hint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hint)

        let textField = NSTextField()
        textField.placeholderString = "Safari, Xcode"
        textField.font = Styles.bodyFont
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.target = self
        textField.action = #selector(fieldChanged)
        container.addSubview(textField)
        self.appTokenField = textField

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            hint.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 2),
            hint.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            hint.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            textField.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 6),
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
        ])

        return yOffset + 70
    }

    private func addNumberField(label: String, placeholder: String, unit: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.font = Styles.bodyFont
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.target = self
        textField.action = #selector(fieldChanged)
        container.addSubview(textField)
        self.numberField = textField

        let unitLabel = Styles.label(unit, font: Styles.captionFont, color: Styles.secondaryLabel)
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(unitLabel)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            textField.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            textField.widthAnchor.constraint(equalToConstant: 80),
            unitLabel.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 8),
            unitLabel.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
        ])

        // Determine which config key to use based on recipe type
        if recipe.type == .cleanDownloads {
            fieldValues["days"] = placeholder
        } else if recipe.type == .volume {
            fieldValues["volume"] = placeholder
        }

        return yOffset + 50
    }

    private func addURLList(label: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView()
        textView.font = Styles.bodyFont
        textView.isEditable = true
        textView.isRichText = false
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView
        container.addSubview(scrollView)
        self.urlTextView = textView

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            scrollView.heightAnchor.constraint(equalToConstant: 80),
        ])

        return yOffset + 110
    }

    private func addDropdown(label: String, key: String, options: [String], to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.removeAllItems()
        for option in options {
            popup.addItem(withTitle: option.capitalized)
            popup.lastItem?.representedObject = option
        }
        popup.target = self
        popup.action = #selector(fieldChanged)
        popup.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(popup)
        self.dropdownPopup = popup
        self.dropdownKey = key

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            popup.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            popup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
        ])

        // Set default
        fieldValues[key] = options.first ?? ""

        return yOffset + 50
    }

    // MARK: - Reading values

    /// Collect all current field values into the config dictionary.
    private func collectValues() -> [String: String] {
        var config = fieldValues

        // Time picker
        if let hourPicker = hourPicker, let selected = hourPicker.selectedItem {
            config["hour"] = "\(selected.tag)"
        }
        if let minutePicker = minutePicker, let selected = minutePicker.selectedItem {
            config["minute"] = "\(selected.tag)"
        }

        // Weekday picker
        let selectedDays = weekdayButtons.filter { $0.state == .on }.map { "\($0.tag)" }
        config["weekdays"] = selectedDays.joined(separator: ",")

        // App picker
        if let text = appTokenField?.stringValue, !text.isEmpty {
            config["apps"] = text
        }

        // URL list
        if let text = urlTextView?.string, !text.isEmpty {
            config["urls"] = text
        }

        // Number field
        if let text = numberField?.stringValue, !text.isEmpty {
            if recipe.type == .cleanDownloads {
                config["days"] = text
            } else if recipe.type == .volume {
                config["volume"] = text
            }
        }

        // Dropdown
        if let key = dropdownKey, let popup = dropdownPopup,
           let value = popup.selectedItem?.representedObject as? String {
            config[key] = value
        }

        return config
    }

    private func updateSentence() {
        let config = collectValues()
        let text = recipe.sentence(config: config)
        sentenceLabel.stringValue = text
        sentenceLabel.textColor = .labelColor
    }

    // MARK: - Actions

    @objc private func fieldChanged() {
        updateSentence()
    }

    @objc private func weekdayChanged() {
        updateSentence()
    }

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func saveTapped() {
        let config = collectValues()

        // Validate
        if let error = recipe.validate(config: config) {
            errorLabel.stringValue = error
            errorLabel.isHidden = false
            return
        }
        errorLabel.isHidden = true

        // Create and save the automation
        let automation = Automation(recipeType: recipe.type, config: config)
        onSave?(automation)
    }
}

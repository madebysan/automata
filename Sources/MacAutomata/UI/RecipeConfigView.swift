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
    private var appCheckboxes: [NSButton] = []       // App picker checkboxes
    private var filePathLabel: NSTextField?            // File picker display
    private var folderLabels: [String: NSTextField] = [:] // Folder picker displays
    private var textFields: [String: NSTextField] = [:]  // Generic text fields by key
    private var urlTextView: NSTextView?
    private var numberField: NSTextField?
    private var dropdownPopup: NSPopUpButton?
    private var dropdownKey: String?

    /// Existing automation being edited (nil for new automations).
    private var editingAutomation: Automation?

    init(recipe: RecipeProvider, editing automation: Automation? = nil) {
        self.recipe = recipe
        self.editingAutomation = automation
        super.init(frame: .zero)
        // Pre-fill field values from existing automation
        if let config = automation?.config {
            self.fieldValues = config
        }
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
        let saveLabel = editingAutomation != nil ? "Update Automation" : "Save Automation"
        let saveButton = Styles.accentButton(saveLabel, target: self, action: #selector(saveTapped))
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

        // Show initial sentence
        updateSentence()
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
        case .filePicker(let label):
            return addFilePicker(label: label, to: container, at: yOffset, padding: padding)
        case .folderPicker(let label, let key):
            return addFolderPicker(label: label, key: key, to: container, at: yOffset, padding: padding)
        case .textField(let label, let placeholder, let key):
            return addTextField(label: label, placeholder: placeholder, key: key, to: container, at: yOffset, padding: padding)
        case .toggle:
            return yOffset
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
        // Pre-select from existing config or default to 9 AM
        let initialHour = Int(fieldValues["hour"] ?? "9") ?? 9
        hourPopup.selectItem(at: initialHour)
        hourPopup.target = self
        hourPopup.action = #selector(fieldChanged)
        hourPopup.translatesAutoresizingMaskIntoConstraints = false
        self.hourPicker = hourPopup

        let minutePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        minutePopup.removeAllItems()
        let initialMinute = Int(fieldValues["minute"] ?? "0") ?? 0
        for m in stride(from: 0, to: 60, by: 5) {
            minutePopup.addItem(withTitle: String(format: ":%02d", m))
            minutePopup.lastItem?.tag = m
        }
        // Select the matching minute (index = minute / 5)
        minutePopup.selectItem(at: initialMinute / 5)
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

        // Parse existing weekday selection or default to Mon-Fri
        let existingDays: Set<Int>
        if let daysStr = fieldValues["weekdays"], !daysStr.isEmpty {
            existingDays = Set(daysStr.split(separator: ",").compactMap { Int($0) })
        } else {
            existingDays = [2, 3, 4, 5, 6] // Mon-Fri
        }

        var buttons: [NSView] = []
        for (i, name) in dayNames.enumerated() {
            let btn = NSButton(checkboxWithTitle: name, target: self, action: #selector(weekdayChanged))
            btn.tag = i + 1
            btn.font = Styles.captionFont
            btn.state = existingDays.contains(i + 1) ? .on : .off
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

        fieldValues["weekdays"] = "2,3,4,5,6"

        return yOffset + 50
    }

    // App picker: scrollable list of checkboxes for installed apps
    private func addAppPicker(label: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let apps = AppDiscoveryService.installedApps()
        appCheckboxes = []

        // Parse existing app selection for editing
        let existingApps = Set(
            (fieldValues["apps"] ?? "").split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
        )

        // Scrollable list of app checkboxes
        let listScroll = NSScrollView()
        listScroll.translatesAutoresizingMaskIntoConstraints = false
        listScroll.hasVerticalScroller = true
        listScroll.borderType = .bezelBorder
        listScroll.drawsBackground = true

        let listContent = FlippedView()
        listContent.translatesAutoresizingMaskIntoConstraints = false
        listScroll.documentView = listContent

        var checkY: CGFloat = 4
        for appName in apps {
            let checkbox = NSButton(checkboxWithTitle: appName, target: self, action: #selector(appCheckboxChanged))
            checkbox.font = Styles.bodyFont
            if existingApps.contains(appName) { checkbox.state = .on }
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            listContent.addSubview(checkbox)
            appCheckboxes.append(checkbox)

            NSLayoutConstraint.activate([
                checkbox.topAnchor.constraint(equalTo: listContent.topAnchor, constant: checkY),
                checkbox.leadingAnchor.constraint(equalTo: listContent.leadingAnchor, constant: 8),
                checkbox.trailingAnchor.constraint(lessThanOrEqualTo: listContent.trailingAnchor, constant: -8),
            ])
            checkY += 22
        }

        // Set content size for scrolling
        let contentHeight = listContent.heightAnchor.constraint(equalToConstant: checkY + 4)
        contentHeight.priority = .defaultLow
        contentHeight.isActive = true

        container.addSubview(listScroll)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            listScroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            listScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            listScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            listScroll.heightAnchor.constraint(equalToConstant: 150),
            listContent.leadingAnchor.constraint(equalTo: listScroll.leadingAnchor),
            listContent.trailingAnchor.constraint(equalTo: listScroll.trailingAnchor),
            listContent.widthAnchor.constraint(equalTo: listScroll.widthAnchor),
        ])

        return yOffset + 176
    }

    // File picker: button that opens a file chooser dialog
    private func addFilePicker(label: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let chooseButton = NSButton(title: "Choose File\u{2026}", target: self, action: #selector(chooseFileTapped))
        chooseButton.bezelStyle = .rounded
        chooseButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chooseButton)

        // Show existing file path if editing
        let existingFile = fieldValues["filePath"] ?? ""
        let displayText = existingFile.isEmpty ? "No file selected" : (existingFile as NSString).lastPathComponent
        let displayColor: NSColor = existingFile.isEmpty ? Styles.secondaryLabel : .labelColor
        let pathLabel = Styles.label(displayText, font: Styles.captionFont, color: displayColor)
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.lineBreakMode = .byTruncatingMiddle
        container.addSubview(pathLabel)
        self.filePathLabel = pathLabel

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            chooseButton.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            chooseButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            pathLabel.centerYAnchor.constraint(equalTo: chooseButton.centerYAnchor),
            pathLabel.leadingAnchor.constraint(equalTo: chooseButton.trailingAnchor, constant: 10),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -padding),
        ])

        return yOffset + 52
    }

    // Folder picker: button that opens a folder chooser dialog
    private func addFolderPicker(label: String, key: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let chooseButton = NSButton(title: "Choose Folder\u{2026}", target: self, action: #selector(chooseFolderTapped(_:)))
        chooseButton.bezelStyle = .rounded
        chooseButton.translatesAutoresizingMaskIntoConstraints = false
        // Store the key so we know which fieldValues entry to update
        objc_setAssociatedObject(chooseButton, "folderKey", key, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        container.addSubview(chooseButton)

        let existing = fieldValues[key] ?? ""
        let displayText = existing.isEmpty ? "No folder selected" : (existing as NSString).lastPathComponent
        let displayColor: NSColor = existing.isEmpty ? Styles.secondaryLabel : .labelColor
        let pathLabel = Styles.label(displayText, font: Styles.captionFont, color: displayColor)
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.lineBreakMode = .byTruncatingMiddle
        container.addSubview(pathLabel)
        folderLabels[key] = pathLabel

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            chooseButton.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            chooseButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            pathLabel.centerYAnchor.constraint(equalTo: chooseButton.centerYAnchor),
            pathLabel.leadingAnchor.constraint(equalTo: chooseButton.trailingAnchor, constant: 10),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -padding),
        ])

        return yOffset + 52
    }

    // Generic text field for simple string input (e.g., reminder message)
    private func addTextField(label: String, placeholder: String, key: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let field = NSTextField()
        field.placeholderString = placeholder
        field.font = Styles.bodyFont
        field.translatesAutoresizingMaskIntoConstraints = false
        field.stringValue = fieldValues[key] ?? ""
        field.target = self
        field.action = #selector(fieldChanged)
        container.addSubview(field)
        textFields[key] = field

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: yOffset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            field.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
        ])

        return yOffset + 50
    }

    private func addNumberField(label: String, placeholder: String, unit: String, to container: NSView, at yOffset: CGFloat, padding: CGFloat) -> CGFloat {
        let header = Styles.sectionHeader(label)
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let textField = NSTextField()
        textField.font = Styles.bodyFont
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.target = self
        textField.action = #selector(fieldChanged)
        container.addSubview(textField)
        self.numberField = textField

        // Pre-fill from existing config or use placeholder
        if recipe.type == .cleanDownloads {
            let existing = fieldValues["days"] ?? ""
            textField.stringValue = existing.isEmpty ? "" : existing
            textField.placeholderString = placeholder
            if existing.isEmpty { fieldValues["days"] = placeholder }
        } else if recipe.type == .volume {
            let existing = fieldValues["volume"] ?? ""
            textField.stringValue = existing.isEmpty ? "" : existing
            textField.placeholderString = placeholder
            if existing.isEmpty { fieldValues["volume"] = placeholder }
        } else if recipe.type == .intervalNotify {
            let existing = fieldValues["interval"] ?? ""
            textField.stringValue = existing.isEmpty ? "" : existing
            textField.placeholderString = placeholder
            if existing.isEmpty { fieldValues["interval"] = placeholder }
        } else {
            textField.placeholderString = placeholder
        }

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
        let existingValue = fieldValues[key] ?? ""
        for (i, option) in options.enumerated() {
            popup.addItem(withTitle: option.capitalized)
            popup.lastItem?.representedObject = option
            if option == existingValue { popup.selectItem(at: i) }
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

        fieldValues[key] = options.first ?? ""

        return yOffset + 50
    }

    // MARK: - Reading values

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

        // App picker — read from checkboxes
        let selectedApps = appCheckboxes.filter { $0.state == .on }.map { $0.title }
        if !selectedApps.isEmpty {
            config["apps"] = selectedApps.joined(separator: ",")
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
            } else if recipe.type == .intervalNotify {
                config["interval"] = text
            }
        }

        // Dropdown
        if let key = dropdownKey, let popup = dropdownPopup,
           let value = popup.selectedItem?.representedObject as? String {
            config[key] = value
        }

        // Generic text fields (by key)
        for (key, field) in textFields {
            let text = field.stringValue
            if !text.isEmpty {
                config[key] = text
            }
        }

        // Folder pickers — already in fieldValues via chooseFolderTapped
        // File picker — already in fieldValues["filePath"]

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

    @objc private func appCheckboxChanged() {
        updateSentence()
    }

    @objc private func chooseFolderTapped(_ sender: NSButton) {
        guard let key = objc_getAssociatedObject(sender, "folderKey") as? String else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder"

        if panel.runModal() == .OK, let url = panel.url {
            fieldValues[key] = url.path
            folderLabels[key]?.stringValue = url.lastPathComponent
            folderLabels[key]?.textColor = .labelColor
            updateSentence()
        }
    }

    @objc private func chooseFileTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a file to open on schedule"

        if panel.runModal() == .OK, let url = panel.url {
            fieldValues["filePath"] = url.path
            filePathLabel?.stringValue = url.lastPathComponent
            filePathLabel?.textColor = .labelColor
            updateSentence()
        }
    }

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func saveTapped() {
        let config = collectValues()

        if let error = recipe.validate(config: config) {
            errorLabel.stringValue = error
            errorLabel.isHidden = false
            return
        }
        errorLabel.isHidden = true

        if var existing = editingAutomation {
            // Editing: update the existing automation's config
            existing.config = config
            onSave?(existing)
        } else {
            // New: create a fresh automation
            let automation = Automation(recipeType: recipe.type, config: config)
            onSave?(automation)
        }
    }
}

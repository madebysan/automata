import Cocoa

// The "When [trigger], Do [action]" builder UI.
// Two dropdowns at the top, dynamic config fields below each,
// live preview sentence, and a save button.
class AutomationBuilder: NSView {

    var onSave: ((Automation) -> Void)?
    var onCancel: (() -> Void)?

    // State
    private var selectedTrigger: TriggerType = .scheduledTime
    private var selectedAction: ActionType = .openApps
    private var triggerValues: [String: String] = [:]
    private var actionValues: [String: String] = [:]
    private var editing: Automation?

    // UI references
    private var triggerDropdown: NSPopUpButton!
    private var actionDropdown: NSPopUpButton!
    private var triggerFieldsContainer: NSStackView!
    private var actionFieldsContainer: NSStackView!
    private var builderTitleLabel: NSTextField!
    private var sentenceLabel: NSTextField!
    private var errorLabel: NSTextField!

    // True only when editing an automation already saved to the manifest
    private var isExistingAutomation: Bool {
        guard let id = editing?.id else { return false }
        return ManifestService.shared.automation(byId: id) != nil
    }

    // Field references for reading values
    private var hourPicker: NSPopUpButton?
    private var minutePicker: NSPopUpButton?
    private var startHourPicker: NSPopUpButton?
    private var startMinutePicker: NSPopUpButton?
    private var endHourPicker: NSPopUpButton?
    private var endMinutePicker: NSPopUpButton?
    private var weekdayButtons: [NSButton] = []
    private var appCheckboxes: [NSButton] = []
    private var appCheckboxNames: [String] = []
    private var quitAllCheckbox: NSButton?
    private var folderLabels: [String: NSTextField] = [:]
    private var textFields: [String: NSTextField] = [:]
    private var numberFields: [String: NSTextField] = [:]
    private var filePathLabel: NSTextField?
    private var urlTextView: NSTextView?
    private var dropdowns: [String: NSPopUpButton] = [:]

    init(editing automation: Automation? = nil) {
        self.editing = automation
        if let a = automation {
            self.selectedTrigger = a.triggerType
            self.selectedAction = a.actionType
            self.triggerValues = a.triggerConfig
            self.actionValues = a.actionConfig
        }
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

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

        // Cancel button — proper rounded style so it's visible (fix #8)
        let cancelBtn = NSButton(title: "\u{2190} Back", target: self, action: #selector(cancelTapped))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(cancelBtn)
        pin(cancelBtn, in: content, top: y, leading: pad)
        y += 36

        // Title
        builderTitleLabel = Styles.label("", font: Styles.titleFont)
        builderTitleLabel.maximumNumberOfLines = 1
        builderTitleLabel.cell?.lineBreakMode = .byTruncatingTail
        builderTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(builderTitleLabel)
        pin(builderTitleLabel, in: content, top: y, leading: pad, trailing: -pad)
        y += 44

        // ── WHEN section ── (fix #1: bigger, bolder, visible label)
        let whenLabel = Styles.label("When", font: NSFont.systemFont(ofSize: 15, weight: .semibold), color: .secondaryLabelColor)
        whenLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(whenLabel)
        pin(whenLabel, in: content, top: y, leading: pad)
        y += 24

        triggerDropdown = NSPopUpButton(frame: .zero, pullsDown: false)
        triggerDropdown.removeAllItems()
        for (i, t) in TriggerType.allCases.enumerated() {
            triggerDropdown.addItem(withTitle: t.name)
            triggerDropdown.lastItem?.tag = i
            if t == selectedTrigger { triggerDropdown.selectItem(at: i) }
        }
        triggerDropdown.target = self
        triggerDropdown.action = #selector(triggerChanged)
        triggerDropdown.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(triggerDropdown)
        pin(triggerDropdown, in: content, top: y, leading: pad)
        y += 34

        // Trigger fields container
        triggerFieldsContainer = NSStackView()
        triggerFieldsContainer.orientation = .vertical
        triggerFieldsContainer.alignment = .leading
        triggerFieldsContainer.spacing = 12
        triggerFieldsContainer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(triggerFieldsContainer)
        NSLayoutConstraint.activate([
            triggerFieldsContainer.topAnchor.constraint(equalTo: content.topAnchor, constant: y),
            triggerFieldsContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            triggerFieldsContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
        ])

        buildTriggerFields()
        y += estimateFieldsHeight(selectedTrigger.fields) + 16

        // ── Divider between sections (fix #7) ──
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: content.topAnchor, constant: y),
            divider.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            divider.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
        ])
        y += 16

        // ── DO THIS section ── (fix #1: bigger, bolder, visible label)
        let doLabel = Styles.label("Do this", font: NSFont.systemFont(ofSize: 15, weight: .semibold), color: .secondaryLabelColor)
        doLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(doLabel)
        pin(doLabel, in: content, top: y, leading: pad)
        y += 24

        actionDropdown = NSPopUpButton(frame: .zero, pullsDown: false)
        actionDropdown.removeAllItems()
        for (i, a) in ActionType.allCases.enumerated() {
            actionDropdown.addItem(withTitle: a.name)
            actionDropdown.lastItem?.tag = i
            if a == selectedAction { actionDropdown.selectItem(at: i) }
        }
        actionDropdown.target = self
        actionDropdown.action = #selector(actionChanged)
        actionDropdown.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(actionDropdown)
        pin(actionDropdown, in: content, top: y, leading: pad)
        y += 34

        // Action fields container
        actionFieldsContainer = NSStackView()
        actionFieldsContainer.orientation = .vertical
        actionFieldsContainer.alignment = .leading
        actionFieldsContainer.spacing = 12
        actionFieldsContainer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(actionFieldsContainer)
        NSLayoutConstraint.activate([
            actionFieldsContainer.topAnchor.constraint(equalTo: content.topAnchor, constant: y),
            actionFieldsContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            actionFieldsContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
        ])

        buildActionFields()

        // ── Error label ──
        // Fixed height so hidden/shown state doesn't shift layout
        errorLabel = Styles.label("", font: Styles.captionFont, color: .systemRed)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.isHidden = true
        content.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: actionFieldsContainer.bottomAnchor, constant: 20),
            errorLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            errorLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            errorLabel.heightAnchor.constraint(equalToConstant: 16),
        ])

        // ── Preview ──
        let previewLabel = Styles.label("Preview", font: NSFont.systemFont(ofSize: 15, weight: .semibold), color: .secondaryLabelColor)
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(previewLabel)
        NSLayoutConstraint.activate([
            previewLabel.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 8),
            previewLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
        ])

        let previewCard = NSBox()
        previewCard.boxType = .custom
        previewCard.cornerRadius = 8
        previewCard.fillColor = NSColor.controlBackgroundColor
        previewCard.borderColor = NSColor.separatorColor.withAlphaComponent(0.3)
        previewCard.borderWidth = 0.5
        previewCard.titlePosition = .noTitle
        previewCard.contentViewMargins = NSSize(width: 14, height: 10)
        previewCard.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(previewCard)

        sentenceLabel = Styles.label("", font: NSFont.systemFont(ofSize: 14, weight: .medium))
        sentenceLabel.translatesAutoresizingMaskIntoConstraints = false
        previewCard.contentView?.addSubview(sentenceLabel)
        if let cv = previewCard.contentView {
            NSLayoutConstraint.activate([
                sentenceLabel.topAnchor.constraint(equalTo: cv.topAnchor),
                sentenceLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                sentenceLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
                sentenceLabel.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            ])
        }
        NSLayoutConstraint.activate([
            previewCard.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 8),
            previewCard.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            previewCard.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            previewCard.heightAnchor.constraint(equalToConstant: 44),
        ])

        // ── Save button ──
        let saveTitle = isExistingAutomation ? "Update Automation" : "Save Automation"
        let saveBtn = Styles.accentButton(saveTitle, target: self, action: #selector(saveTapped))
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(saveBtn)
        NSLayoutConstraint.activate([
            saveBtn.topAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: 16),
            saveBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
        ])

        // Content height is now driven by the actual save button position — no estimate needed
        let h = content.bottomAnchor.constraint(equalTo: saveBtn.bottomAnchor, constant: pad)
        h.priority = .defaultLow
        h.isActive = true

        updateSentence()
        updateDropdownCompatibility()
    }

    // MARK: - Build fields

    private func buildTriggerFields() {
        clearFieldRefs(forTrigger: true)
        triggerFieldsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for field in selectedTrigger.fields {
            let view = buildField(field, values: &triggerValues, isTrigger: true)
            triggerFieldsContainer.addArrangedSubview(view)
        }
        if selectedTrigger.fields.isEmpty {
            let hint = Styles.label("No configuration needed.", font: Styles.bodyFont, color: Styles.tertiaryLabel)
            triggerFieldsContainer.addArrangedSubview(hint)
        }
    }

    private func buildActionFields() {
        clearFieldRefs(forTrigger: false)
        actionFieldsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var fields = selectedAction.fields

        // moveFiles needs an explicit source folder when the trigger isn't fileAppears
        if selectedAction == .moveFiles && selectedTrigger != .fileAppears {
            fields.insert(.folderPicker(label: "Move files from", key: "sourceFolder"), at: 0)
        }

        // keepAwake in a time range: duration is set by the range itself, not a dropdown
        if selectedAction == .keepAwake && selectedTrigger == .timeRange {
            fields = []
        }

        // setVolume in a time range: add a "restore to" field for the end script
        if selectedAction == .setVolume && selectedTrigger == .timeRange {
            fields.append(.numberInput(label: "After range, restore to", placeholder: "50", unit: "%", key: "revertVolume"))
        }

        for field in fields {
            let view = buildField(field, values: &actionValues, isTrigger: false)
            actionFieldsContainer.addArrangedSubview(view)
        }
        if fields.isEmpty {
            let hint = Styles.label("No configuration needed.", font: Styles.bodyFont, color: Styles.tertiaryLabel)
            actionFieldsContainer.addArrangedSubview(hint)
        }
    }

    private func buildField(_ field: BuilderField, values: inout [String: String], isTrigger: Bool) -> NSView {
        switch field {
        case .timePicker:
            return makeTimePicker(values: &values)
        case .startTimePicker:
            return makeTimePicker(label: "From", prefix: "start", values: &values)
        case .endTimePicker:
            return makeTimePicker(label: "To", prefix: "end", values: &values)
        case .weekdayPicker:
            return makeWeekdayPicker(values: &values)
        case .appPicker(let label, _, let allowAll):
            return makeAppPicker(label: label, allowAll: allowAll, values: &values)
        case .filePicker(let label):
            return makeFilePicker(label: label, values: &values)
        case .folderPicker(let label, let key):
            return makeFolderPicker(label: label, key: key, values: &values)
        case .urlList(let label):
            return makeURLList(label: label, values: &values)
        case .numberInput(let label, let placeholder, let unit, let key):
            return makeNumberInput(label: label, placeholder: placeholder, unit: unit, key: key, values: &values)
        case .textInput(let label, let placeholder, let key):
            return makeTextInput(label: label, placeholder: placeholder, key: key, values: &values)
        case .dropdown(let label, let key, let options):
            return makeDropdown(label: label, key: key, options: options, values: &values)
        }
    }

    // MARK: - Field constructors

    private func makeTimePicker(label: String? = nil, prefix: String = "", values: inout [String: String]) -> NSView {
        let hourKey   = prefix.isEmpty ? "hour"   : "\(prefix)Hour"
        let minuteKey = prefix.isEmpty ? "minute" : "\(prefix)Minute"

        let hour = NSPopUpButton(frame: .zero, pullsDown: false)
        hour.removeAllItems()
        let initH = Int(values[hourKey] ?? "9") ?? 9
        for h in 0..<24 {
            let p = h >= 12 ? "PM" : "AM"
            let d = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            hour.addItem(withTitle: "\(d) \(p)")
            hour.lastItem?.tag = h
        }
        hour.selectItem(at: initH)
        hour.target = self; hour.action = #selector(fieldChanged)

        let minute = NSPopUpButton(frame: .zero, pullsDown: false)
        minute.removeAllItems()
        let initM = Int(values[minuteKey] ?? "0") ?? 0
        for m in stride(from: 0, to: 60, by: 5) {
            minute.addItem(withTitle: String(format: ":%02d", m))
            minute.lastItem?.tag = m
        }
        minute.selectItem(at: initM / 5)
        minute.target = self; minute.action = #selector(fieldChanged)

        // Store references by prefix
        switch prefix {
        case "start": startHourPicker = hour; startMinutePicker = minute
        case "end":   endHourPicker   = hour; endMinutePicker   = minute
        default:      self.hourPicker = hour; self.minutePicker  = minute
        }

        values[hourKey]   = "\(initH)"
        values[minuteKey] = "\(initM)"

        let pickers = NSStackView(views: [hour, minute])
        pickers.orientation = .horizontal; pickers.spacing = 8

        if let label = label {
            let lbl = Styles.label(label, font: Styles.bodyFont, color: Styles.secondaryLabel)
            lbl.widthAnchor.constraint(equalToConstant: 34).isActive = true
            let row = NSStackView(views: [lbl, pickers])
            row.orientation = .horizontal; row.spacing = 10
            return row
        }
        return pickers
    }

    // Fix #3: wider spacing on weekday checkboxes
    private func makeWeekdayPicker(values: inout [String: String]) -> NSView {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let existing: Set<Int>
        if let s = values["weekdays"], !s.isEmpty {
            existing = Set(s.split(separator: ",").compactMap { Int($0) })
        } else {
            existing = [2, 3, 4, 5, 6]
            values["weekdays"] = "2,3,4,5,6"
        }
        weekdayButtons = []
        var btns: [NSView] = []
        for (i, name) in names.enumerated() {
            let b = NSButton(checkboxWithTitle: name, target: self, action: #selector(fieldChanged))
            b.tag = i + 1; b.font = Styles.bodyFont
            b.state = existing.contains(i + 1) ? .on : .off
            weekdayButtons.append(b); btns.append(b)
        }
        let row = NSStackView(views: btns)
        row.orientation = .horizontal; row.spacing = 10
        return row
    }

    // App list with icon, checkbox, and app name per row
    private func makeAppPicker(label: String, allowAll: Bool = false, values: inout [String: String]) -> NSView {
        let apps = AppDiscoveryService.installedApps()
        let existing = Set((values["apps"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        appCheckboxes = []
        appCheckboxNames = []

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .lineBorder
        scroll.drawsBackground = true
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 6

        let list = FlippedView()
        list.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = list

        let rowHeight: CGFloat = 30
        var cy: CGFloat = 4

        // "All open apps" row — only shown for quitApps
        quitAllCheckbox = nil
        if allowAll {
            let allRow = NSView()
            allRow.translatesAutoresizingMaskIntoConstraints = false
            list.addSubview(allRow)

            let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(quitAllTapped))
            cb.state = values["quitAll"] == "true" ? .on : .off
            cb.translatesAutoresizingMaskIntoConstraints = false
            allRow.addSubview(cb)
            quitAllCheckbox = cb

            let lbl = NSTextField(labelWithString: "All open apps")
            lbl.font = NSFont.systemFont(ofSize: Styles.bodyFont.pointSize, weight: .medium)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            allRow.addSubview(lbl)

            NSLayoutConstraint.activate([
                allRow.topAnchor.constraint(equalTo: list.topAnchor, constant: cy),
                allRow.leadingAnchor.constraint(equalTo: list.leadingAnchor, constant: 8),
                allRow.trailingAnchor.constraint(equalTo: list.trailingAnchor, constant: -8),
                allRow.heightAnchor.constraint(equalToConstant: rowHeight),
                cb.leadingAnchor.constraint(equalTo: allRow.leadingAnchor),
                cb.centerYAnchor.constraint(equalTo: allRow.centerYAnchor),
                lbl.leadingAnchor.constraint(equalTo: cb.trailingAnchor, constant: 10),
                lbl.centerYAnchor.constraint(equalTo: allRow.centerYAnchor),
            ])
            cy += rowHeight

            // Divider below the "All open apps" row
            let div = NSBox()
            div.boxType = .separator
            div.translatesAutoresizingMaskIntoConstraints = false
            list.addSubview(div)
            NSLayoutConstraint.activate([
                div.topAnchor.constraint(equalTo: list.topAnchor, constant: cy),
                div.leadingAnchor.constraint(equalTo: list.leadingAnchor, constant: 8),
                div.trailingAnchor.constraint(equalTo: list.trailingAnchor, constant: -8),
            ])
            cy += 8
        }

        for (name, path) in apps {
            let row = NSView()
            row.translatesAutoresizingMaskIntoConstraints = false
            list.addSubview(row)

            // Checkbox (no title — name is tracked in appCheckboxNames)
            let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(fieldChanged))
            if existing.contains(name) { cb.state = .on }
            cb.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(cb)
            appCheckboxes.append(cb)
            appCheckboxNames.append(name)

            // App icon from the bundle on disk
            let iconView = NSImageView()
            iconView.image = NSWorkspace.shared.icon(forFile: path)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.wantsLayer = true
            iconView.layer?.cornerRadius = 4
            iconView.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(iconView)

            // App name label
            let nameLabel = NSTextField(labelWithString: name)
            nameLabel.font = Styles.bodyFont
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(nameLabel)

            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: list.topAnchor, constant: cy),
                row.leadingAnchor.constraint(equalTo: list.leadingAnchor, constant: 8),
                row.trailingAnchor.constraint(equalTo: list.trailingAnchor, constant: -8),
                row.heightAnchor.constraint(equalToConstant: rowHeight),

                cb.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                cb.centerYAnchor.constraint(equalTo: row.centerYAnchor),

                iconView.leadingAnchor.constraint(equalTo: cb.trailingAnchor, constant: 6),
                iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 20),
                iconView.heightAnchor.constraint(equalToConstant: 20),

                nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor),
            ])
            cy += rowHeight
        }
        let ch = list.heightAnchor.constraint(equalToConstant: cy + 4)
        ch.priority = .defaultLow; ch.isActive = true

        NSLayoutConstraint.activate([
            scroll.heightAnchor.constraint(equalToConstant: 200),
            list.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            list.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])
        return scroll
    }

    private func makeFilePicker(label: String, values: inout [String: String]) -> NSView {
        let btn = NSButton(title: "Choose File\u{2026}", target: self, action: #selector(chooseFileTapped))
        btn.bezelStyle = .rounded
        let existing = values["filePath"] ?? ""
        let lbl = Styles.label(
            existing.isEmpty ? "No file selected" : (existing as NSString).lastPathComponent,
            font: Styles.bodyFont,
            color: existing.isEmpty ? Styles.secondaryLabel : .labelColor
        )
        self.filePathLabel = lbl
        let row = NSStackView(views: [btn, lbl])
        row.orientation = .horizontal; row.spacing = 10
        return row
    }

    private func makeFolderPicker(label: String, key: String, values: inout [String: String]) -> NSView {
        let btn = NSButton(title: "\(label)\u{2026}", target: self, action: #selector(chooseFolderTapped(_:)))
        btn.bezelStyle = .rounded
        btn.identifier = NSUserInterfaceItemIdentifier(key)
        let existing = values[key] ?? ""
        let lbl = Styles.label(
            existing.isEmpty ? "No folder selected" : (existing as NSString).lastPathComponent,
            font: Styles.bodyFont,
            color: existing.isEmpty ? Styles.secondaryLabel : .labelColor
        )
        folderLabels[key] = lbl
        let row = NSStackView(views: [btn, lbl])
        row.orientation = .horizontal; row.spacing = 10
        return row
    }

    private func makeURLList(label: String, values: inout [String: String]) -> NSView {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .lineBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 6
        let tv = NSTextView()
        tv.font = Styles.bodyFont; tv.isEditable = true; tv.isRichText = false
        tv.string = values["urls"] ?? ""
        tv.autoresizingMask = [.width]
        scroll.documentView = tv
        self.urlTextView = tv
        scroll.heightAnchor.constraint(equalToConstant: 70).isActive = true

        let hint = Styles.label("One URL per line — https://example.com", font: Styles.captionFont, color: Styles.tertiaryLabel)
        let stack = NSStackView(views: [scroll, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }

    private func makeNumberInput(label: String, placeholder: String, unit: String, key: String, values: inout [String: String]) -> NSView {
        let field = NSTextField()
        field.placeholderString = placeholder; field.font = Styles.bodyFont
        field.stringValue = values[key] ?? ""
        field.target = self; field.action = #selector(fieldChanged)
        field.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let fmt = NumberFormatter()
        fmt.numberStyle = .none
        fmt.minimum = 0
        fmt.allowsFloats = false
        field.formatter = fmt
        numberFields[key] = field
        if values[key] == nil { values[key] = placeholder }

        let unitLbl = Styles.label(unit, font: Styles.bodyFont, color: Styles.secondaryLabel)
        let row = NSStackView(views: [field, unitLbl])
        row.orientation = .horizontal; row.spacing = 8
        return row
    }

    private func makeTextInput(label: String, placeholder: String, key: String, values: inout [String: String]) -> NSView {
        let field = NSTextField()
        field.placeholderString = placeholder; field.font = Styles.bodyFont
        field.stringValue = values[key] ?? ""
        field.target = self; field.action = #selector(fieldChanged)
        textFields[key] = field

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        field.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(field)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: container.topAnchor),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 24),
        ])
        return container
    }

    private func makeDropdown(label: String, key: String, options: [String], values: inout [String: String]) -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.removeAllItems()
        let existing = values[key] ?? ""
        for (i, opt) in options.enumerated() {
            popup.addItem(withTitle: opt.capitalized)
            popup.lastItem?.representedObject = opt
            if opt == existing { popup.selectItem(at: i) }
        }
        popup.target = self; popup.action = #selector(fieldChanged)
        dropdowns[key] = popup
        if values[key] == nil { values[key] = options.first ?? "" }
        return popup
    }

    // MARK: - Collect values

    private func collectTriggerValues() -> [String: String] {
        var v = triggerValues
        if let h = hourPicker?.selectedItem       { v["hour"]        = "\(h.tag)" }
        if let m = minutePicker?.selectedItem     { v["minute"]      = "\(m.tag)" }
        if let h = startHourPicker?.selectedItem  { v["startHour"]   = "\(h.tag)" }
        if let m = startMinutePicker?.selectedItem { v["startMinute"] = "\(m.tag)" }
        if let h = endHourPicker?.selectedItem    { v["endHour"]     = "\(h.tag)" }
        if let m = endMinutePicker?.selectedItem  { v["endMinute"]   = "\(m.tag)" }
        if !weekdayButtons.isEmpty {
            v["weekdays"] = weekdayButtons.filter { $0.state == .on }.map { "\($0.tag)" }.joined(separator: ",")
        }
        for (key, field) in numberFields where selectedTrigger.fields.contains(where: { if case .numberInput(_, _, _, let k) = $0 { return k == key } else { return false } }) {
            v[key] = field.stringValue
        }
        return v
    }

    private func collectActionValues() -> [String: String] {
        var v = actionValues
        if quitAllCheckbox?.state == .on {
            v["quitAll"] = "true"
        } else {
            v.removeValue(forKey: "quitAll")
        }
        if !appCheckboxes.isEmpty {
            let selected = zip(appCheckboxes, appCheckboxNames).filter { $0.0.state == .on }.map { $0.1 }
            v["apps"] = selected.isEmpty ? "" : selected.joined(separator: ",")
        }
        if let text = urlTextView?.string, !text.isEmpty { v["urls"] = text }
        for (key, field) in textFields { v[key] = field.stringValue }
        for (key, field) in numberFields {
            if selectedAction.fields.contains(where: { if case .numberInput(_, _, _, let k) = $0 { return k == key } else { return false } }) {
                v[key] = field.stringValue
            }
        }
        for (key, popup) in dropdowns {
            if let val = popup.selectedItem?.representedObject as? String { v[key] = val }
        }
        return v
    }

    private func updateSentence() {
        let tc = collectTriggerValues()
        let ac = collectActionValues()
        let when = selectedTrigger.sentenceFragment(config: tc)
        let what = selectedAction.sentenceFragment(config: ac)
        let sentence = "\(when), \(what)"
        sentenceLabel?.stringValue = sentence
        builderTitleLabel?.stringValue = sentence
    }

    // MARK: - Actions

    @objc private func triggerChanged() {
        let idx = triggerDropdown.indexOfSelectedItem
        guard idx >= 0, idx < TriggerType.allCases.count else { return }
        selectedTrigger = TriggerType.allCases[idx]
        triggerValues = [:]
        buildTriggerFields()

        // Auto-switch action if it's incompatible with the newly chosen trigger
        if !selectedAction.compatibleTriggers.contains(selectedTrigger) {
            if let compat = ActionType.allCases.first(where: { $0.compatibleTriggers.contains(selectedTrigger) }),
               let compatIdx = ActionType.allCases.firstIndex(of: compat) {
                selectedAction = compat
                actionValues = [:]
                actionDropdown.selectItem(at: compatIdx)
                buildActionFields()
            }
        }

        updateDropdownCompatibility()
        updateSentence()
    }

    @objc private func actionChanged() {
        let idx = actionDropdown.indexOfSelectedItem
        guard idx >= 0, idx < ActionType.allCases.count else { return }
        selectedAction = ActionType.allCases[idx]
        actionValues = [:]
        buildActionFields()

        // Auto-switch trigger if it's incompatible with the newly chosen action
        if !selectedAction.compatibleTriggers.contains(selectedTrigger) {
            if let compat = TriggerType.allCases.first(where: { selectedAction.compatibleTriggers.contains($0) }),
               let compatIdx = TriggerType.allCases.firstIndex(of: compat) {
                selectedTrigger = compat
                triggerValues = [:]
                triggerDropdown.selectItem(at: compatIdx)
                buildTriggerFields()
            }
        }

        updateDropdownCompatibility()
        updateSentence()
    }

    /// Grays out dropdown items that are incompatible with the current selection on the other side.
    private func updateDropdownCompatibility() {
        for (i, action) in ActionType.allCases.enumerated() {
            actionDropdown.item(at: i)?.isEnabled = action.compatibleTriggers.contains(selectedTrigger)
        }
        for (i, trigger) in TriggerType.allCases.enumerated() {
            triggerDropdown.item(at: i)?.isEnabled = selectedAction.compatibleTriggers.contains(trigger)
        }
    }

    @objc private func fieldChanged() { updateSentence() }

    @objc private func quitAllTapped() {
        let isAll = quitAllCheckbox?.state == .on
        // Gray out individual app checkboxes when "All open apps" is active
        appCheckboxes.forEach { $0.isEnabled = !isAll }
        if isAll {
            actionValues["quitAll"] = "true"
        } else {
            actionValues.removeValue(forKey: "quitAll")
        }
        updateSentence()
    }

    @objc private func chooseFileTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            actionValues["filePath"] = url.path
            filePathLabel?.stringValue = url.lastPathComponent
            filePathLabel?.textColor = .labelColor
            updateSentence()
        }
    }

    @objc private func chooseFolderTapped(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            if selectedTrigger.fields.contains(where: { if case .folderPicker(_, let k) = $0 { return k == key } else { return false } }) {
                triggerValues[key] = url.path
            } else {
                actionValues[key] = url.path
            }
            folderLabels[key]?.stringValue = url.lastPathComponent
            folderLabels[key]?.textColor = .labelColor
            updateSentence()
        }
    }

    @objc private func cancelTapped() { onCancel?() }

    @objc private func saveTapped() {
        let tc = collectTriggerValues()
        let ac = collectActionValues()

        if selectedTrigger == .fileAppears {
            if (tc["watchFolder"] ?? "").isEmpty {
                showError("Please choose a folder to watch"); return
            }
        } else if selectedTrigger == .interval {
            guard let intervalStr = tc["interval"], let mins = Int(intervalStr), mins > 0 else {
                showError("Please enter a number of minutes (must be > 0)"); return
            }
        }

        // moveFiles with a non-fileAppears trigger needs an explicit source folder
        if selectedAction == .moveFiles && selectedTrigger != .fileAppears {
            if (ac["sourceFolder"] ?? "").isEmpty {
                showError("Please choose a folder to move files from"); return
            }
        }

        if let err = selectedAction.validate(config: ac) {
            showError(err); return
        }

        errorLabel.isHidden = true

        if var existing = editing {
            existing.triggerConfig = tc
            existing.actionConfig = ac
            onSave?(existing)
        } else {
            let automation = Automation(
                triggerType: selectedTrigger,
                triggerConfig: tc,
                actionType: selectedAction,
                actionConfig: ac
            )
            onSave?(automation)
        }
    }

    private func showError(_ msg: String) {
        errorLabel.stringValue = msg
        errorLabel.isHidden = false
    }

    // MARK: - Helpers

    private func clearFieldRefs(forTrigger: Bool) {
        if forTrigger {
            hourPicker = nil; minutePicker = nil; weekdayButtons = []
            startHourPicker = nil; startMinutePicker = nil
            endHourPicker   = nil; endMinutePicker   = nil
        } else {
            appCheckboxes = []; appCheckboxNames = []; quitAllCheckbox = nil; filePathLabel = nil; urlTextView = nil
            textFields = [:]; dropdowns = [:]
        }
        if forTrigger {
            numberFields = numberFields.filter { key, _ in
                !selectedTrigger.fields.contains(where: { if case .numberInput(_, _, _, let k) = $0 { return k == key } else { return false } })
            }
            folderLabels = folderLabels.filter { key, _ in
                !selectedTrigger.fields.contains(where: { if case .folderPicker(_, let k) = $0 { return k == key } else { return false } })
            }
        } else {
            numberFields = numberFields.filter { key, _ in
                !selectedAction.fields.contains(where: { if case .numberInput(_, _, _, let k) = $0 { return k == key } else { return false } })
            }
            folderLabels = folderLabels.filter { key, _ in
                !selectedAction.fields.contains(where: { if case .folderPicker(_, let k) = $0 { return k == key } else { return false } })
            }
        }
    }

    private func estimateFieldsHeight(_ fields: [BuilderField]) -> CGFloat {
        if fields.isEmpty { return 24 }
        var h: CGFloat = 0
        for f in fields {
            switch f {
            case .timePicker, .startTimePicker, .endTimePicker: h += 34
            case .weekdayPicker: h += 30
            case .appPicker: h += 160
            case .filePicker, .folderPicker: h += 34
            case .urlList: h += 80
            case .numberInput, .textInput: h += 34
            case .dropdown: h += 34
            }
        }
        return h
    }

    private func pin(_ view: NSView, in container: NSView, top: CGFloat, leading: CGFloat, trailing: CGFloat? = nil) {
        var constraints = [
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: top),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leading),
        ]
        if let t = trailing {
            constraints.append(view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: t))
        }
        NSLayoutConstraint.activate(constraints)
    }
}

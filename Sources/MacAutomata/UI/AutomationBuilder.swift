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
    private var sentenceLabel: NSTextField!
    private var errorLabel: NSTextField!

    // Field references for reading values
    private var hourPicker: NSPopUpButton?
    private var minutePicker: NSPopUpButton?
    private var weekdayButtons: [NSButton] = []
    private var appCheckboxes: [NSButton] = []
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

        // Cancel button (top-left)
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelBtn.bezelStyle = .inline
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(cancelBtn)
        pin(cancelBtn, in: content, top: y, leading: pad)
        y += 30

        // Title
        let titleText = editing != nil ? "Edit Automation" : "New Automation"
        let title = Styles.label(titleText, font: Styles.titleFont)
        title.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(title)
        pin(title, in: content, top: y, leading: pad, trailing: -pad)
        y += 40

        // ── WHEN section ──
        let whenHeader = Styles.sectionHeader("When")
        whenHeader.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(whenHeader)
        pin(whenHeader, in: content, top: y, leading: pad)
        y += 20

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
        y += estimateFieldsHeight(selectedTrigger.fields) + 20

        // ── DO THIS section ──
        let doHeader = Styles.sectionHeader("Do this")
        doHeader.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(doHeader)
        pin(doHeader, in: content, top: y, leading: pad)
        y += 20

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
        y += estimateFieldsHeight(selectedAction.fields) + 20

        // ── Error label ──
        errorLabel = Styles.label("", font: Styles.captionFont, color: .systemRed)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.isHidden = true
        content.addSubview(errorLabel)
        pin(errorLabel, in: content, top: y, leading: pad, trailing: -pad)
        y += 16

        // ── Preview ──
        let previewHeader = Styles.sectionHeader("Preview")
        previewHeader.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(previewHeader)
        pin(previewHeader, in: content, top: y, leading: pad)
        y += 20

        sentenceLabel = Styles.label("", font: NSFont.systemFont(ofSize: 14, weight: .medium))
        sentenceLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sentenceLabel)
        pin(sentenceLabel, in: content, top: y, leading: pad, trailing: -pad)
        y += 40

        // ── Save button ──
        let saveTitle = editing != nil ? "Update Automation" : "Save Automation"
        let saveBtn = Styles.accentButton(saveTitle, target: self, action: #selector(saveTapped))
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(saveBtn)
        NSLayoutConstraint.activate([
            saveBtn.topAnchor.constraint(equalTo: content.topAnchor, constant: y),
            saveBtn.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            saveBtn.widthAnchor.constraint(equalToConstant: 200),
        ])
        y += 60

        let h = content.heightAnchor.constraint(equalToConstant: y)
        h.priority = .defaultLow
        h.isActive = true

        updateSentence()
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
            let hint = Styles.label("No configuration needed.", font: Styles.captionFont, color: Styles.tertiaryLabel)
            triggerFieldsContainer.addArrangedSubview(hint)
        }
    }

    private func buildActionFields() {
        clearFieldRefs(forTrigger: false)
        actionFieldsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for field in selectedAction.fields {
            let view = buildField(field, values: &actionValues, isTrigger: false)
            actionFieldsContainer.addArrangedSubview(view)
        }
        if selectedAction.fields.isEmpty {
            let hint = Styles.label("No configuration needed.", font: Styles.captionFont, color: Styles.tertiaryLabel)
            actionFieldsContainer.addArrangedSubview(hint)
        }
    }

    private func buildField(_ field: BuilderField, values: inout [String: String], isTrigger: Bool) -> NSView {
        switch field {
        case .timePicker:
            return makeTimePicker(values: &values)
        case .weekdayPicker:
            return makeWeekdayPicker(values: &values)
        case .appPicker(let label, _):
            return makeAppPicker(label: label, values: &values)
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

    private func makeTimePicker(values: inout [String: String]) -> NSView {
        let hour = NSPopUpButton(frame: .zero, pullsDown: false)
        hour.removeAllItems()
        let initH = Int(values["hour"] ?? "9") ?? 9
        for h in 0..<24 {
            let p = h >= 12 ? "PM" : "AM"
            let d = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            hour.addItem(withTitle: "\(d) \(p)")
            hour.lastItem?.tag = h
        }
        hour.selectItem(at: initH)
        hour.target = self; hour.action = #selector(fieldChanged)
        self.hourPicker = hour

        let minute = NSPopUpButton(frame: .zero, pullsDown: false)
        minute.removeAllItems()
        let initM = Int(values["minute"] ?? "0") ?? 0
        for m in stride(from: 0, to: 60, by: 5) {
            minute.addItem(withTitle: String(format: ":%02d", m))
            minute.lastItem?.tag = m
        }
        minute.selectItem(at: initM / 5)
        minute.target = self; minute.action = #selector(fieldChanged)
        self.minutePicker = minute

        values["hour"] = "\(initH)"
        values["minute"] = "\(initM)"

        let row = NSStackView(views: [hour, minute])
        row.orientation = .horizontal; row.spacing = 8
        return row
    }

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
            b.tag = i + 1; b.font = Styles.captionFont
            b.state = existing.contains(i + 1) ? .on : .off
            weekdayButtons.append(b); btns.append(b)
        }
        let row = NSStackView(views: btns)
        row.orientation = .horizontal; row.spacing = 4
        return row
    }

    private func makeAppPicker(label: String, values: inout [String: String]) -> NSView {
        let apps = AppDiscoveryService.installedApps()
        let existing = Set((values["apps"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        appCheckboxes = []

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder; scroll.drawsBackground = true

        let list = FlippedView()
        list.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = list

        var cy: CGFloat = 4
        for name in apps {
            let cb = NSButton(checkboxWithTitle: name, target: self, action: #selector(fieldChanged))
            cb.font = Styles.bodyFont
            if existing.contains(name) { cb.state = .on }
            cb.translatesAutoresizingMaskIntoConstraints = false
            list.addSubview(cb); appCheckboxes.append(cb)
            NSLayoutConstraint.activate([
                cb.topAnchor.constraint(equalTo: list.topAnchor, constant: cy),
                cb.leadingAnchor.constraint(equalTo: list.leadingAnchor, constant: 8),
            ])
            cy += 22
        }
        let ch = list.heightAnchor.constraint(equalToConstant: cy + 4)
        ch.priority = .defaultLow; ch.isActive = true

        NSLayoutConstraint.activate([
            scroll.heightAnchor.constraint(equalToConstant: 140),
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
            font: Styles.captionFont,
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
        objc_setAssociatedObject(btn, "folderKey", key, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        let existing = values[key] ?? ""
        let lbl = Styles.label(
            existing.isEmpty ? "No folder selected" : (existing as NSString).lastPathComponent,
            font: Styles.captionFont,
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
        scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        let tv = NSTextView()
        tv.font = Styles.bodyFont; tv.isEditable = true; tv.isRichText = false
        tv.string = values["urls"] ?? ""
        tv.autoresizingMask = [.width]
        scroll.documentView = tv
        self.urlTextView = tv
        scroll.heightAnchor.constraint(equalToConstant: 70).isActive = true
        return scroll
    }

    private func makeNumberInput(label: String, placeholder: String, unit: String, key: String, values: inout [String: String]) -> NSView {
        let field = NSTextField()
        field.placeholderString = placeholder; field.font = Styles.bodyFont
        field.stringValue = values[key] ?? ""
        field.target = self; field.action = #selector(fieldChanged)
        field.widthAnchor.constraint(equalToConstant: 80).isActive = true
        numberFields[key] = field
        if values[key] == nil { values[key] = placeholder }

        let unitLbl = Styles.label(unit, font: Styles.captionFont, color: Styles.secondaryLabel)
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
        if let h = hourPicker?.selectedItem { v["hour"] = "\(h.tag)" }
        if let m = minutePicker?.selectedItem { v["minute"] = "\(m.tag)" }
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
        if !appCheckboxes.isEmpty {
            let selected = appCheckboxes.filter { $0.state == .on }.map { $0.title }
            if !selected.isEmpty { v["apps"] = selected.joined(separator: ",") }
        }
        if let text = urlTextView?.string, !text.isEmpty { v["urls"] = text }
        for (key, field) in textFields { v[key] = field.stringValue }
        for (key, field) in numberFields {
            // Only collect if this key belongs to the action
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
        sentenceLabel.stringValue = "\(when), \(what)"
    }

    // MARK: - Actions

    @objc private func triggerChanged() {
        let idx = triggerDropdown.indexOfSelectedItem
        guard idx >= 0, idx < TriggerType.allCases.count else { return }
        selectedTrigger = TriggerType.allCases[idx]
        triggerValues = [:]
        buildTriggerFields()
        updateSentence()
    }

    @objc private func actionChanged() {
        let idx = actionDropdown.indexOfSelectedItem
        guard idx >= 0, idx < ActionType.allCases.count else { return }
        selectedAction = ActionType.allCases[idx]
        actionValues = [:]
        buildActionFields()
        updateSentence()
    }

    @objc private func fieldChanged() { updateSentence() }

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
        guard let key = objc_getAssociatedObject(sender, "folderKey") as? String else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            // Determine if this is a trigger or action field
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

        // Validate trigger
        if selectedTrigger == .fileAppears {
            if (tc["watchFolder"] ?? "").isEmpty {
                showError("Please choose a folder to watch"); return
            }
        } else if selectedTrigger == .interval {
            if Int(tc["interval"] ?? "") == nil || Int(tc["interval"] ?? "0")! <= 0 {
                showError("Please enter a number of minutes (must be > 0)"); return
            }
        }

        // Validate action
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
        } else {
            appCheckboxes = []; filePathLabel = nil; urlTextView = nil
            textFields = [:]; dropdowns = [:]
        }
        // Number fields and folder labels may belong to either
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
            case .timePicker: h += 30
            case .weekdayPicker: h += 28
            case .appPicker: h += 150
            case .filePicker, .folderPicker: h += 30
            case .urlList: h += 80
            case .numberInput, .textInput: h += 30
            case .dropdown: h += 30
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

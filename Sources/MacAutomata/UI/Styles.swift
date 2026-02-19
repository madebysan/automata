import Cocoa

// An NSView with a flipped (top-left) coordinate origin.
// Required as the documentView of NSScrollView so content
// starts at the top instead of floating at the bottom.
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// Shared visual constants for all windows.
// Keeps the look consistent without repeating magic numbers.
enum Styles {

    // MARK: - Colors

    static let accentColor = NSColor.controlAccentColor
    static let secondaryLabel = NSColor.secondaryLabelColor
    static let tertiaryLabel = NSColor.tertiaryLabelColor
    static let windowBackground = NSColor.windowBackgroundColor
    static let cardBackground = NSColor.controlBackgroundColor
    static let separator = NSColor.separatorColor

    // Category colors for the two-icon visual pattern (IFTTT-inspired)
    static let scheduleColor = NSColor.systemBlue
    static let appColor = NSColor.systemOrange
    static let fileColor = NSColor.systemYellow
    static let systemColor = NSColor.systemPurple
    static let cleanupColor = NSColor.systemTeal
    static let webColor = NSColor.systemIndigo
    static let audioColor = NSColor.systemPink

    // MARK: - Fonts

    static let titleFont = NSFont.systemFont(ofSize: 22, weight: .bold)
    static let headlineFont = NSFont.systemFont(ofSize: 15, weight: .medium)
    static let bodyFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    static let captionFont = NSFont.systemFont(ofSize: 11, weight: .regular)
    static let smallBoldFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let sentenceFont = NSFont.systemFont(ofSize: 13, weight: .regular)

    // MARK: - Spacing

    static let windowPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 8
    static let cardCornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let bottomBarPadding: CGFloat = 16
    static let headerGroupSpacing: CGFloat = 4

    // MARK: - Icon Sizes

    static let heroIconSize: CGFloat = 56
    static let cardIconSize: CGFloat = 20
    static let sidebarIconSize: CGFloat = 13
    static let statusBarIconSize: CGFloat = 16
    static let recipeIconSize: CGFloat = 28

    // MARK: - Window Sizes

    static let mainWindowSize = NSSize(width: 520, height: 600)
    static let configSheetSize = NSSize(width: 480, height: 400)

    // MARK: - Helpers

    /// Create a standard label with the given text and font.
    static func label(_ text: String, font: NSFont = bodyFont, color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = font
        field.textColor = color
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        return field
    }

    /// Create a section header label — small, uppercase, tertiary color.
    static func sectionHeader(_ text: String) -> NSTextField {
        let field = label(text.uppercased(), font: smallBoldFont, color: tertiaryLabel)
        if let attrStr = field.attributedStringValue.mutableCopy() as? NSMutableAttributedString {
            attrStr.addAttribute(.kern, value: 0.8, range: NSRange(location: 0, length: attrStr.length))
            field.attributedStringValue = attrStr
        }
        return field
    }

    /// Create a rounded card-style box view.
    static func cardView() -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = cardCornerRadius
        box.fillColor = cardBackground
        box.borderColor = separator.withAlphaComponent(0.3)
        box.borderWidth = 0.5
        box.titlePosition = .noTitle
        box.contentViewMargins = NSSize(width: cardPadding, height: cardPadding)
        return box
    }

    /// A primary action button styled as the key equivalent (accent-tinted).
    static func accentButton(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.controlSize = .large
        return button
    }
}

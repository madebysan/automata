import Foundation

// Unified field types used by both triggers and actions.
// The AutomationBuilder renders these dynamically.
enum BuilderField {
    case timePicker
    case startTimePicker   // uses startHour / startMinute keys
    case endTimePicker     // uses endHour / endMinute keys
    case weekdayPicker
    case appPicker(label: String, multiple: Bool, allowAll: Bool = false)
    case filePicker(label: String)
    case folderPicker(label: String, key: String)
    case urlList(label: String)
    case numberInput(label: String, placeholder: String, unit: String, key: String)
    case textInput(label: String, placeholder: String, key: String)
    case dropdown(label: String, key: String, options: [String])
}

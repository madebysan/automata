import Foundation

// Parses natural language descriptions into ranked automation suggestions.
// Scores all action+trigger combinations and returns the best matches.
// Pure local parsing — no LLM, no network requests.
enum NLParser {

    // MARK: - Public types

    struct Suggestion {
        let triggerType: TriggerType
        let actionType: ActionType
        let triggerConfig: [String: String]
        let actionConfig: [String: String]
        let score: Double           // 0.0 to 1.0
        let summary: String         // e.g. "Switch to dark mode every day at 10:00 PM"
        let missingFields: [String] // fields the user still needs to fill
    }

    struct ParseResult {
        let suggestions: [Suggestion]    // ranked, 0-3 items
        let matchedTemplates: [Template] // templates that overlap with the parse
    }

    // MARK: - Public API

    static func parse(_ input: String) -> ParseResult {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return ParseResult(suggestions: [], matchedTemplates: [])
        }

        // Score every action and trigger independently
        let actionScores = ActionType.allCases.map { (action: $0, score: scoreAction($0, in: text)) }
        let triggerScores = TriggerType.allCases.map { (trigger: $0, score: scoreTrigger($0, in: text)) }

        // Build all valid candidates: top actions × compatible triggers
        var candidates: [Suggestion] = []
        let topActions = actionScores.filter { $0.score > 0 }.sorted { $0.score > $1.score }

        for actionEntry in topActions.prefix(3) {
            let action = actionEntry.action
            let compatible = action.compatibleTriggers

            // Pair with each trigger that scored > 0 and is compatible
            let viableTriggers = triggerScores
                .filter { $0.score > 0 && compatible.contains($0.trigger) }
                .sorted { $0.score > $1.score }

            if viableTriggers.isEmpty {
                // Action matched but no trigger matched — pick the best compatible default
                let bestDefault = bestDefaultTrigger(for: action)
                let (tConfig, tMissing) = extractTriggerConfig(bestDefault, from: text)
                let (aConfig, aMissing) = extractActionConfig(action, from: text)
                let configBonus = Double(tConfig.count + aConfig.count) * 0.05
                let score = normalize(actionEntry.score + configBonus)
                let summary = buildSummary(trigger: bestDefault, triggerConfig: tConfig,
                                           action: action, actionConfig: aConfig)
                candidates.append(Suggestion(
                    triggerType: bestDefault, actionType: action,
                    triggerConfig: tConfig, actionConfig: aConfig,
                    score: score, summary: summary,
                    missingFields: tMissing + aMissing
                ))
            } else {
                for triggerEntry in viableTriggers.prefix(2) {
                    let trigger = triggerEntry.trigger
                    let (tConfig, tMissing) = extractTriggerConfig(trigger, from: text)
                    let (aConfig, aMissing) = extractActionConfig(action, from: text)
                    let configBonus = Double(tConfig.count + aConfig.count) * 0.05
                    let score = normalize(actionEntry.score + triggerEntry.score + configBonus)
                    let summary = buildSummary(trigger: trigger, triggerConfig: tConfig,
                                               action: action, actionConfig: aConfig)
                    candidates.append(Suggestion(
                        triggerType: trigger, actionType: action,
                        triggerConfig: tConfig, actionConfig: aConfig,
                        score: score, summary: summary,
                        missingFields: tMissing + aMissing
                    ))
                }
            }
        }

        // Deduplicate by action+trigger pair, keeping highest score
        var seen = Set<String>()
        var unique: [Suggestion] = []
        for c in candidates.sorted(by: { $0.score > $1.score }) {
            let key = "\(c.actionType.rawValue)+\(c.triggerType.rawValue)"
            if seen.insert(key).inserted {
                unique.append(c)
            }
        }

        let suggestions = Array(unique.prefix(3))

        // Match templates that overlap with top-scoring action
        let matchedTemplates: [Template]
        if let topAction = suggestions.first?.actionType {
            matchedTemplates = TemplateLibrary.all.filter { $0.actionType == topAction }
        } else {
            // No action matched — try fuzzy template name matching
            matchedTemplates = TemplateLibrary.all.filter { template in
                let name = template.name.lowercased()
                return text.contains(name) || fuzzyContains(text, name, maxDistance: 2)
            }
        }

        return ParseResult(
            suggestions: suggestions,
            matchedTemplates: Array(matchedTemplates.prefix(3))
        )
    }

    // MARK: - Action scoring

    private struct KeywordGroup {
        let keywords: [String]
        let weight: Double
    }

    private static func scoreAction(_ action: ActionType, in text: String) -> Double {
        let groups = actionKeywords(action, text: text)
        return scoreKeywordGroups(groups, in: text)
    }

    private static func actionKeywords(_ action: ActionType, text: String) -> [KeywordGroup] {
        switch action {
        case .darkMode:
            return [
                KeywordGroup(keywords: ["dark mode", "night mode", "light mode"], weight: 0.4),
                KeywordGroup(keywords: ["dark", "light", "appearance"], weight: 0.2),
                KeywordGroup(keywords: ["theme", "display mode"], weight: 0.1),
            ]
        case .setVolume:
            return [
                KeywordGroup(keywords: ["set volume", "volume to", "mute", "unmute"], weight: 0.4),
                KeywordGroup(keywords: ["volume", "sound", "audio"], weight: 0.2),
                KeywordGroup(keywords: ["loud", "quiet", "silent"], weight: 0.1),
            ]
        case .emptyTrash:
            return [
                KeywordGroup(keywords: ["empty trash", "empty the trash"], weight: 0.4),
                KeywordGroup(keywords: ["clear trash", "trash"], weight: 0.2),
                KeywordGroup(keywords: ["clean up", "delete trash"], weight: 0.1),
            ]
        case .openApps:
            return [
                KeywordGroup(keywords: ["open app", "launch app", "start app", "open apps"], weight: 0.4),
                KeywordGroup(keywords: ["open", "launch", "run"], weight: 0.15),
                KeywordGroup(keywords: matchedAppKeywords(in: text), weight: 0.25),
            ]
        case .quitApps:
            return [
                KeywordGroup(keywords: ["quit app", "close app", "kill app", "quit apps", "close apps"], weight: 0.4),
                KeywordGroup(keywords: ["quit", "close", "stop"], weight: 0.15),
                KeywordGroup(keywords: ["shut down", "exit"], weight: 0.1),
            ]
        case .showNotification:
            return [
                KeywordGroup(keywords: ["remind me", "notification", "alert me", "send notification"], weight: 0.4),
                KeywordGroup(keywords: ["remind", "alert", "notify"], weight: 0.2),
                KeywordGroup(keywords: ["tell me", "popup", "reminder"], weight: 0.1),
            ]
        case .cleanDownloads:
            return [
                KeywordGroup(keywords: ["clean downloads", "clear downloads", "clean up downloads"], weight: 0.4),
                KeywordGroup(keywords: ["old downloads", "old files"], weight: 0.2),
                KeywordGroup(keywords: ["cleanup"], weight: 0.1),
            ]
        case .moveFiles:
            return [
                KeywordGroup(keywords: ["move files", "move to folder", "move file"], weight: 0.4),
                KeywordGroup(keywords: ["organize files", "sort files"], weight: 0.2),
                KeywordGroup(keywords: ["file to", "put files"], weight: 0.1),
            ]
        case .openURLs:
            return [
                KeywordGroup(keywords: ["open url", "open website", "open link", "open urls"], weight: 0.4),
                KeywordGroup(keywords: ["url", "website", "link"], weight: 0.15),
                KeywordGroup(keywords: ["browse", "go to"], weight: 0.1),
            ]
        case .openFile:
            return [
                KeywordGroup(keywords: ["open file", "open document", "open a file"], weight: 0.4),
                KeywordGroup(keywords: ["open the file"], weight: 0.2),
                KeywordGroup(keywords: ["file"], weight: 0.05),
            ]
        case .keepAwake:
            return [
                KeywordGroup(keywords: ["keep awake", "stay awake", "don't sleep", "dont sleep"], weight: 0.4),
                KeywordGroup(keywords: ["awake", "caffeinate"], weight: 0.2),
                KeywordGroup(keywords: ["prevent sleep", "no sleep"], weight: 0.15),
            ]
        }
    }

    // If the input mentions installed app names, return them as keywords
    // so openApps/quitApps can score from app names alone.
    private static func matchedAppKeywords(in text: String) -> [String] {
        let apps = AppDiscoveryService.installedApps()
        return apps.compactMap { app in
            text.contains(app.name.lowercased()) ? app.name.lowercased() : nil
        }
    }

    // MARK: - Trigger scoring

    private static func scoreTrigger(_ trigger: TriggerType, in text: String) -> Double {
        let groups = triggerKeywords(trigger)
        var score = scoreKeywordGroups(groups, in: text)

        // Bonus: if a time value was extracted and trigger is time-based, boost it
        if trigger == .scheduledTime && extractTime(from: text) != nil {
            score += 0.15
        }
        if trigger == .interval && extractInterval(from: text) != nil {
            score += 0.15
        }
        if trigger == .timeRange && text.contains("between") {
            score += 0.1
        }

        return score
    }

    private static func triggerKeywords(_ trigger: TriggerType) -> [KeywordGroup] {
        switch trigger {
        case .scheduledTime:
            return [
                KeywordGroup(keywords: ["every day at", "every weekday at", "every monday",
                                        "every tuesday", "every wednesday", "every thursday",
                                        "every friday", "every saturday", "every sunday"], weight: 0.35),
                KeywordGroup(keywords: ["at", "when it's", "every night", "every morning"], weight: 0.1),
                KeywordGroup(keywords: ["daily", "nightly"], weight: 0.1),
            ]
        case .interval:
            return [
                KeywordGroup(keywords: ["every 5 minutes", "every 10 minutes", "every 15 minutes",
                                        "every 20 minutes", "every 30 minutes", "every 60 minutes",
                                        "every hour", "every 2 hours", "every half hour",
                                        "every 1 hour", "every 3 hours"], weight: 0.4),
                KeywordGroup(keywords: ["repeatedly", "on repeat", "hourly"], weight: 0.2),
                KeywordGroup(keywords: ["periodic", "periodically"], weight: 0.1),
            ]
        case .onLogin:
            return [
                KeywordGroup(keywords: ["on login", "at startup", "when i log in",
                                        "when i sign in", "on startup", "at login"], weight: 0.4),
                KeywordGroup(keywords: ["login", "startup", "boot"], weight: 0.15),
                KeywordGroup(keywords: ["start up", "sign in", "log in"], weight: 0.1),
            ]
        case .fileAppears:
            return [
                KeywordGroup(keywords: ["when a file appears", "when files appear",
                                        "when a file is added", "when files are added"], weight: 0.4),
                KeywordGroup(keywords: ["file appears", "new file"], weight: 0.25),
                KeywordGroup(keywords: ["file drops", "file added"], weight: 0.15),
            ]
        case .driveMount:
            return [
                KeywordGroup(keywords: ["when a drive is mounted", "when usb", "when sd card",
                                        "when i plug in", "when drive is plugged"], weight: 0.4),
                KeywordGroup(keywords: ["drive mount", "external drive", "usb drive"], weight: 0.25),
                KeywordGroup(keywords: ["plug in", "connect drive"], weight: 0.15),
            ]
        case .timeRange:
            return [
                KeywordGroup(keywords: ["between", "from morning to", "from evening to"], weight: 0.2),
                KeywordGroup(keywords: ["during", "during the"], weight: 0.15),
                KeywordGroup(keywords: ["hours of"], weight: 0.1),
            ]
        }
    }

    // MARK: - Keyword scoring engine

    private static func scoreKeywordGroups(_ groups: [KeywordGroup], in text: String) -> Double {
        var total = 0.0
        for group in groups {
            var groupHit = false
            for keyword in group.keywords {
                if keyword.isEmpty { continue }
                if text.contains(keyword) {
                    // Exact phrase match
                    total += group.weight
                    groupHit = true
                    break
                } else if keyword.count >= 4 && fuzzyContains(text, keyword, maxDistance: 2) {
                    // Fuzzy match for longer keywords (catches typos)
                    total += group.weight * 0.7
                    groupHit = true
                    break
                }
            }
            // Small compound bonus for hitting multiple groups
            if groupHit && total > group.weight {
                total += 0.03
            }
        }
        return total
    }

    // MARK: - Value extractors

    /// Extract a time like "10pm", "10:30 PM", "22:00", "noon", "midnight"
    static func extractTime(from text: String) -> (hour: Int, minute: Int)? {
        // "noon" / "midnight"
        if text.contains("noon") { return (12, 0) }
        if text.contains("midnight") { return (0, 0) }

        // "10pm", "10 pm", "10:30pm", "10:30 pm", "10 p.m.", "10:30 p.m."
        let pattern = #"(\d{1,2})(?::(\d{2}))?\s*(?:(am|pm|a\.m\.|p\.m\.))"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matched = String(text[match])
            let digits = matched.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            let isPM = matched.contains("pm") || matched.contains("p.m.")
            let isAM = matched.contains("am") || matched.contains("a.m.")
            if let hourStr = digits.first, var hour = Int(hourStr) {
                let minute = digits.count > 1 ? (Int(digits[1]) ?? 0) : 0
                if isPM && hour < 12 { hour += 12 }
                if isAM && hour == 12 { hour = 0 }
                if hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 {
                    return (hour, minute)
                }
            }
        }

        // 24-hour format: "22:00", "09:30"
        let pattern24 = #"(\d{1,2}):(\d{2})"#
        if let match = text.range(of: pattern24, options: .regularExpression) {
            let matched = String(text[match])
            let parts = matched.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 && parts[0] >= 0 && parts[0] <= 23 && parts[1] >= 0 && parts[1] <= 59 {
                return (parts[0], parts[1])
            }
        }

        return nil
    }

    /// Extract weekdays from input
    static func extractWeekdays(from text: String) -> String? {
        if text.contains("every day") || text.contains("daily") || text.contains("every night") {
            return "1,2,3,4,5,6,7"
        }
        if text.contains("weekday") || text.contains("mon-fri") || text.contains("monday to friday") || text.contains("monday through friday") {
            return "2,3,4,5,6"
        }
        if text.contains("weekend") {
            return "1,7"
        }

        // Individual day names
        let dayMap: [(names: [String], value: Int)] = [
            (["sunday", "sun"], 1),
            (["monday", "mon"], 2),
            (["tuesday", "tue", "tues"], 3),
            (["wednesday", "wed"], 4),
            (["thursday", "thu", "thur", "thurs"], 5),
            (["friday", "fri"], 6),
            (["saturday", "sat"], 7),
        ]

        var matched: [Int] = []
        for entry in dayMap {
            for name in entry.names {
                if text.contains(name) {
                    matched.append(entry.value)
                    break
                }
            }
        }

        if !matched.isEmpty {
            return matched.sorted().map(String.init).joined(separator: ",")
        }
        return nil
    }

    /// Extract interval: "every 30 minutes", "every 2 hours", "every hour", "hourly", "every half hour"
    static func extractInterval(from text: String) -> Int? {
        if text.contains("hourly") || text.contains("every hour") { return 60 }
        if text.contains("every half hour") || text.contains("half an hour") { return 30 }

        // "every N minutes"
        let minPattern = #"every\s+(\d+)\s*(?:min|minute)"#
        if let match = text.range(of: minPattern, options: .regularExpression) {
            let matched = String(text[match])
            let digits = matched.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let numStr = digits.first, let num = Int(numStr), num > 0 {
                return num
            }
        }

        // "every N hours"
        let hourPattern = #"every\s+(\d+)\s*hour"#
        if let match = text.range(of: hourPattern, options: .regularExpression) {
            let matched = String(text[match])
            let digits = matched.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let numStr = digits.first, let num = Int(numStr), num > 0 {
                return num * 60
            }
        }

        return nil
    }

    /// Extract a number: "volume to 50", "50%", "older than 30 days"
    static func extractNumber(from text: String) -> Int? {
        // "N%" or "to N"
        let patterns = [#"(\d+)\s*%"#, #"to\s+(\d+)"#, #"(\d+)\s*days?"#]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matched = String(text[match])
                let digits = matched.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if let numStr = digits.first, let num = Int(numStr) {
                    return num
                }
            }
        }
        return nil
    }

    /// Extract dark mode type: "dark mode" → "dark", "light mode" → "light", "toggle" → "toggle"
    static func extractDarkModeType(from text: String) -> String {
        if text.contains("light mode") || text.contains("turn on light") || text.contains("switch to light") {
            return "light"
        }
        if text.contains("toggle") {
            return "toggle"
        }
        return "dark" // default
    }

    /// Extract duration for keepAwake: "for 2 hours", "for 30 minutes"
    static func extractDuration(from text: String) -> String? {
        let validOptions = ["30 min", "1 hour", "2 hours", "4 hours", "8 hours", "12 hours"]

        if text.contains("30 min") || text.contains("30 minute") || text.contains("half hour") {
            return "30 min"
        }

        // "for N hour(s)"
        let hourPattern = #"(?:for\s+)?(\d+)\s*hours?"#
        if let match = text.range(of: hourPattern, options: .regularExpression) {
            let matched = String(text[match])
            let digits = matched.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let numStr = digits.first, let num = Int(numStr) {
                let candidate = num == 1 ? "1 hour" : "\(num) hours"
                if validOptions.contains(candidate) { return candidate }
            }
        }

        return nil
    }

    /// Match app names from the input against installed apps
    static func extractAppNames(from text: String) -> String? {
        let apps = AppDiscoveryService.installedApps()
        var matched: [String] = []
        for app in apps {
            let lower = app.name.lowercased()
            // Only match app names that are 2+ characters to avoid false positives
            if lower.count >= 2 && text.contains(lower) {
                matched.append(app.name)
            }
        }
        return matched.isEmpty ? nil : matched.joined(separator: ",")
    }

    /// Extract text in quotes: "saying X" or text in "quotes"
    static func extractQuotedText(from text: String) -> String? {
        // Text in double or single quotes
        let quotePatterns = [#""([^"]+)""#, #"'([^']+)'"#, #"\u{201c}([^\u{201d}]+)\u{201d}"#]
        for pattern in quotePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        // "saying X" or "that says X"
        let sayingPatterns = [#"saying\s+(.+)"#, #"that says\s+(.+)"#]
        for pattern in sayingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    // MARK: - Config builders

    private static func extractTriggerConfig(_ trigger: TriggerType, from text: String) -> (config: [String: String], missing: [String]) {
        var config: [String: String] = [:]
        var missing: [String] = []

        switch trigger {
        case .scheduledTime:
            if let time = extractTime(from: text) {
                config["hour"] = String(time.hour)
                config["minute"] = String(time.minute)
            } else {
                missing.append("time")
            }
            if let days = extractWeekdays(from: text) {
                config["weekdays"] = days
            } else {
                // Default to every day if no days specified
                config["weekdays"] = "1,2,3,4,5,6,7"
            }

        case .interval:
            if let minutes = extractInterval(from: text) {
                config["interval"] = String(minutes)
            } else {
                missing.append("interval")
            }

        case .onLogin:
            break // No config needed

        case .fileAppears:
            // Can't extract folder path from natural language reliably
            missing.append("watchFolder")

        case .driveMount:
            break // No config needed

        case .timeRange:
            if let time = extractTime(from: text) {
                config["startHour"] = String(time.hour)
                config["startMinute"] = String(time.minute)
            } else {
                missing.append("startTime")
            }
            // Try to extract end time from "between X and Y" or "to Y"
            let andPattern = #"and\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?)"#
            let toPattern = #"to\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?)"#
            for pattern in [andPattern, toPattern] {
                if let match = text.range(of: pattern, options: .regularExpression) {
                    let sub = String(text[match])
                    if let endTime = extractTime(from: sub) {
                        config["endHour"] = String(endTime.hour)
                        config["endMinute"] = String(endTime.minute)
                        break
                    }
                }
            }
            if config["endHour"] == nil { missing.append("endTime") }
            if let days = extractWeekdays(from: text) {
                config["weekdays"] = days
            } else {
                config["weekdays"] = "1,2,3,4,5,6,7"
            }
        }

        return (config, missing)
    }

    private static func extractActionConfig(_ action: ActionType, from text: String) -> (config: [String: String], missing: [String]) {
        var config: [String: String] = [:]
        var missing: [String] = []

        switch action {
        case .darkMode:
            config["mode"] = extractDarkModeType(from: text)

        case .setVolume:
            if let num = extractNumber(from: text), num >= 0, num <= 100 {
                config["volume"] = String(num)
            } else if text.contains("mute") {
                config["volume"] = "0"
            } else {
                missing.append("volume")
            }

        case .emptyTrash:
            break // No config needed

        case .cleanDownloads:
            if let num = extractNumber(from: text), num > 0 {
                config["days"] = String(num)
            } else {
                config["days"] = "30" // sensible default
            }

        case .openApps:
            if let apps = extractAppNames(from: text) {
                config["apps"] = apps
            } else {
                missing.append("apps")
            }

        case .quitApps:
            if text.contains("all open apps") || text.contains("quit all") || text.contains("close all") {
                config["quitAll"] = "true"
            } else if let apps = extractAppNames(from: text) {
                config["apps"] = apps
            } else {
                missing.append("apps")
            }

        case .showNotification:
            if let quoted = extractQuotedText(from: text) {
                config["message"] = quoted
            } else {
                // Try to extract message from common patterns
                let messagePatterns = [
                    #"remind me to\s+(.+?)(?:\s+every|\s+at|\s+on|$)"#,
                    #"reminder to\s+(.+?)(?:\s+every|\s+at|\s+on|$)"#,
                    #"notify(?:\s+me)?\s+to\s+(.+?)(?:\s+every|\s+at|\s+on|$)"#,
                ]
                for pattern in messagePatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                       let range = Range(match.range(at: 1), in: text) {
                        let msg = String(text[range]).trimmingCharacters(in: .whitespaces)
                        if !msg.isEmpty {
                            // Capitalize first letter
                            config["message"] = msg.prefix(1).uppercased() + msg.dropFirst()
                            break
                        }
                    }
                }
                if config["message"] == nil { missing.append("message") }
            }

        case .moveFiles:
            missing.append("destFolder") // Can't reliably extract paths from NL

        case .openURLs:
            missing.append("urls") // Can't reliably extract URLs from NL description

        case .openFile:
            missing.append("filePath") // Can't reliably extract file paths from NL

        case .keepAwake:
            if let duration = extractDuration(from: text) {
                config["duration"] = duration
            } else {
                config["duration"] = "1 hour" // sensible default
            }
        }

        return (config, missing)
    }

    // MARK: - Helpers

    /// Pick the most common default trigger for an action when no trigger was detected.
    private static func bestDefaultTrigger(for action: ActionType) -> TriggerType {
        switch action {
        case .openApps, .quitApps: return .onLogin
        case .darkMode, .setVolume: return .scheduledTime
        case .emptyTrash, .cleanDownloads: return .scheduledTime
        case .showNotification: return .interval
        case .moveFiles: return .fileAppears
        case .openFile, .openURLs: return .scheduledTime
        case .keepAwake: return .scheduledTime
        }
    }

    /// Build a human-readable summary from a parsed suggestion.
    private static func buildSummary(trigger: TriggerType, triggerConfig: [String: String],
                                     action: ActionType, actionConfig: [String: String]) -> String {
        let when = trigger.sentenceFragment(config: triggerConfig)
        let what = action.sentenceFragment(config: actionConfig)
        return "\(when), \(what)"
    }

    /// Normalize a raw score to 0.0-1.0 range.
    private static func normalize(_ raw: Double) -> Double {
        // Typical max raw score is about 0.9-1.1 (action 0.4+0.2 + trigger 0.4+0.15 + config bonus)
        return min(max(raw / 1.0, 0.0), 1.0)
    }

    // MARK: - Fuzzy matching

    /// Check if any word-boundary-aligned substring of `text` is within Levenshtein distance of `keyword`.
    private static func fuzzyContains(_ text: String, _ keyword: String, maxDistance: Int) -> Bool {
        let words = text.split(separator: " ").map(String.init)
        let keyLen = keyword.count

        // Check all substrings of similar length
        for startIdx in 0..<words.count {
            var candidate = ""
            for endIdx in startIdx..<min(startIdx + 4, words.count) {
                if !candidate.isEmpty { candidate += " " }
                candidate += words[endIdx]
                if abs(candidate.count - keyLen) <= maxDistance {
                    if levenshtein(candidate, keyword) <= maxDistance {
                        return true
                    }
                }
            }
        }
        return false
    }

    /// Levenshtein edit distance between two strings.
    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            prev = curr
        }

        return prev[n]
    }
}

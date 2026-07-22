//
//  SwiftDateTimePreparser.swift
//  SwiftAdaptiveCards
//
//  Created by Hugo Gonzalez on 3/07/25.
//

import Foundation

public class SwiftDateTimePreparser {
    private var textTokenCollection: [SwiftDateTimePreparsedToken] = []
    private var hasDateTokens: Bool = false

    public init() {}

    public init(input: String) {
        parseDateTime(input)
    }

    public var textTokens: [SwiftDateTimePreparsedToken] {
        return textTokenCollection
    }
    
    private func addTextToken(_ text: String, format: DateTimePreparsedTokenFormat) {
        guard !text.isEmpty else { return }
        textTokenCollection.append(SwiftDateTimePreparsedToken(text: text, format: format))
    }
    
    private func addDateToken(_ text: String, date: Date, format: DateTimePreparsedTokenFormat) {
        textTokenCollection.append(SwiftDateTimePreparsedToken(text: text, date: date, format: format))
        hasDateTokens = true
    }
    
    /// Revised parser using ISO8601DateFormatter.
    private func parseDateTime(_ input: String) {
        // Our regex matches tokens of the form:
        // {{(DATE|TIME)(...)}}
        let pattern = "\\{\\{(DATE|TIME)\\((.*?)\\)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            addTextToken(input, format: .RegularString)
            return
        }
        
        var currentLocation = input.startIndex
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
        let isoFormatter = ISO8601DateFormatter()
        // Ensure we use the full format that includes time and timezone.
        isoFormatter.formatOptions = [.withInternetDateTime]
        
        for match in matches {
            guard let matchRange = Range(match.range, in: input) else { continue }
            
            // Append any text preceding this match.
            if currentLocation < matchRange.lowerBound {
                let prefixText = String(input[currentLocation..<matchRange.lowerBound])
                addTextToken(prefixText, format: .RegularString)
            }
            
            // Extract token type ("DATE" or "TIME") from capture group 1.
            guard let typeRange = Range(match.range(at: 1), in: input) else { continue }
            let tokenType = String(input[typeRange])
            
            // Capture the inner content (everything inside the parentheses) from group 2.
            guard let innerRange = Range(match.range(at: 2), in: input) else { continue }
            let innerContent = String(input[innerRange])
            // Remove any trailing format specifier by splitting at the comma.
            let components = innerContent.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            // The first component should be the ISO8601 date string.
            let dateString = components.first?.trimmingCharacters(in: .whitespaces) ?? ""
            
            // For DATE tokens, we may need to determine the requested format.
            let requestedFormat: DateTimePreparsedTokenFormat = {
                if components.count > 1 {
                    let spec = components[1].trimmingCharacters(in: .whitespaces).uppercased()
                    switch spec {
                    case "SHORT": return .DateShort
                    case "LONG": return .DateLong
                    case "COMPACT": return .DateCompact
                    default: return .DateCompact
                    }
                } else {
                    // Default for DATE tokens.
                    return .DateCompact
                }
            }()
            
            // Parse the date using ISO8601DateFormatter.
            if let parsedDate = isoFormatter.date(from: dateString) {
                if tokenType == "TIME" {
                    // For TIME tokens, format the parsed date in local time.
                    let outputFormatter = DateFormatter()
                    outputFormatter.timeZone = TimeZone.current // should be Pacific per test environment
                    outputFormatter.dateFormat = "hh:mm a"
                    outputFormatter.locale = Locale(identifier: "en_US_POSIX")
                    let formattedTime = outputFormatter.string(from: parsedDate)
                    addTextToken(formattedTime, format: .RegularString)
                } else {
                    // For DATE tokens, keep the original token text.
                    addDateToken(String(input[matchRange]), date: parsedDate, format: requestedFormat)
                }
            } else {
                // If parsing fails, treat the entire match as regular text.
                addTextToken(String(input[matchRange]), format: .RegularString)
            }
            
            currentLocation = matchRange.upperBound
        }
        
        // Append any remaining text.
        if currentLocation < input.endIndex {
            let trailingText = String(input[currentLocation..<input.endIndex])
            addTextToken(trailingText, format: .RegularString)
        }
    }
    
    public static func tryParseSimpleTime(_ string: String) -> (hours: Int, minutes: Int)? {
        let pattern = #"^(\d{2}):(\d{2})$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        if let match = regex?.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)) {
            let nsString = string as NSString
            let hours = Int(nsString.substring(with: match.range(at: 1))) ?? 0
            let minutes = Int(nsString.substring(with: match.range(at: 2))) ?? 0
            if isValidTime(hours: hours, minutes: minutes) {
                return (hours, minutes)
            }
        }
        return nil
    }
    
    public static func tryParseSimpleDate(_ string: String) -> (year: Int, month: Int, day: Int)? {
        let pattern = #"^(\d{4})-(\d{2})-(\d{2})$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        if let match = regex?.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)) {
            let nsString = string as NSString
            let year = Int(nsString.substring(with: match.range(at: 1))) ?? 0
            let month = Int(nsString.substring(with: match.range(at: 2))) ?? 0
            let day = Int(nsString.substring(with: match.range(at: 3))) ?? 0
            if isValidDate(year: year, month: month, day: day) {
                return (year, month, day)
            }
        }
        return nil
    }
    
    private static func isValidDate(year: Int, month: Int, day: Int) -> Bool {
        guard month > 0 && month <= 12 && day > 0 && day <= 31 else { return false }
        if [4, 6, 9, 11].contains(month) { return day <= 30 }
        if month == 2 {
            return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0) ? day <= 29 : day <= 28
        }
        return true
    }
    
    private static func isValidTime(hours: Int, minutes: Int) -> Bool {
        return hours < 24 && minutes < 60
    }
}

public enum DateTimePreparsedTokenFormat: Equatable, Codable {
    case RegularString
    case DateCompact
    case DateShort
    case DateLong
}

public class SwiftDateTimePreparsedToken: Codable {
    public let text: String
    public let format: DateTimePreparsedTokenFormat
    private var dateValue: Date?

    public init(text: String, format: DateTimePreparsedTokenFormat) {
        self.text = text
        self.format = format
    }
    
    public init(text: String, date: Date, format: DateTimePreparsedTokenFormat) {
        self.text = text
        self.dateValue = date
        self.format = format
    }
    
    /// Returns the day component if a date was parsed; otherwise 0.
    public var day: Int {
        guard let date = dateValue else { return 0 }
        return Calendar.current.component(.day, from: date)
    }
    
    /// Returns the month component (zero-indexed to match C++ tests).
    public var month: Int {
        guard let date = dateValue else { return 0 }
        // Calendar gives 1 for January, so subtract 1.
        return Calendar.current.component(.month, from: date) - 1
    }
    
    /// Returns the year component.
    public var year: Int {
        guard let date = dateValue else { return 0 }
        return Calendar.current.component(.year, from: date)
    }
}

//
//  SwiftUtil.swift
//  SwiftAdaptiveCards
//
//  Created by Hugo Gonzalez on 3/07/25.
//

import Foundation

/// Validates a given hex color string and ensures it is in the correct format.
func validateColor(_ backgroundColor: String, warnings: inout [SwiftAdaptiveCardParseWarning]) -> String {
    // 1. Empty string => no color
    guard !backgroundColor.isEmpty else {
        return backgroundColor  // e.g. "", no changes needed
    }

    // 2. Must start with '#' + either 6 or 8 hex digits
    let length = backgroundColor.count
    let validLengths = [7, 9] // #XXXXXX (7 total) or #XXXXXXXX (9 total)
    guard backgroundColor.first == "#",
          validLengths.contains(length)
    else {
        warnings.append(
            SwiftAdaptiveCardParseWarning(
                statusCode: .invalidColorFormat,
                message: "Image background color specified, but doesn't follow #AARRGGBB or #RRGGBB format"
            )
        )
        return "#00000000"
    }

    // 3. Check that all trailing characters are valid hex
    //    (Swift's .isHexDigit can accept some unexpected Unicode characters, so let's be extra explicit.)
    let hexPart = backgroundColor.dropFirst() // the string after '#'
    let validHexChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
    let allAreValidHex = hexPart.unicodeScalars.allSatisfy { validHexChars.contains($0) }

    if !allAreValidHex {
        warnings.append(
            SwiftAdaptiveCardParseWarning(
                statusCode: .invalidColorFormat,
                message: "Image background color specified, but contains invalid hex characters"
            )
        )
        return "#00000000"
    }

    // 4. If exactly 7 total chars => #RRGGBB => prepend 'FF'
    //    If 9 => #AARRGGBB => keep as is
    if length == 7 {
        // #RRGGBB -> #FF + RRGGBB
        return "#FF\(hexPart)"
    } else {
        // length == 9 => #AARRGGBB => keep original
        return backgroundColor
    }
}


/// Parses an explicit dimension string (e.g. "10px") into a UInt value.
/// If the dimension does not match the expected format (digits with an optional fractional part immediately followed by "px"),
/// a warning is appended and nil is returned.
func parseSizeForPixelSize(_ dimension: String, warnings: inout [SwiftAdaptiveCardParseWarning]) -> UInt? {
    let pattern = "^(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?px$"
    guard let _ = dimension.range(of: pattern, options: .regularExpression) else {
        warnings.append(SwiftAdaptiveCardParseWarning(statusCode: .invalidDimensionSpecified,
                                                   message: "Invalid dimension format: \(dimension)"))
        return nil
    }
    let numberPart = dimension.dropLast(2)
    guard let value = Double(numberPart), value >= 0 else {
        warnings.append(SwiftAdaptiveCardParseWarning(statusCode: .invalidDimensionSpecified,
                                                   message: "Invalid numeric value in dimension: \(dimension)"))
        return nil
    }
    return UInt(floor(value))
}

/// Ensures that all ShowCard actions have the correct version assigned.
func ensureShowCardVersions(_ actions: [SwiftBaseActionElement], version: String) {
    for action in actions {
        if let showCardAction = action as? SwiftShowCardAction, showCardAction.card?.version.isEmpty == true {
            showCardAction.card?.version = version
        }
    }
}

/// Handles unknown properties by extracting properties that are not in the known properties set.
func handleUnknownProperties(from json: [String: Any], knownProperties: Set<String>) -> [String: Any] {
    var unknownProperties: [String: Any] = [:]
    for (key, value) in json where !knownProperties.contains(key) {
        unknownProperties[key] = value
    }
    return unknownProperties
}

/// Validates user input for a dimension with a specified unit.
private func validateUserInputForDimensionWithUnit(_ unit: String, _ requestedDimension: String, warnings: inout [SwiftAdaptiveCardParseWarning]) -> Int? {
    let regexPattern = #"^([1-9]\d*)(\.\d+)?(\#(unit))$"#
    let warningMessage = "Expected input argument to be specified as \\d+(\\.\\d+)?px with no spaces, but received \(requestedDimension)"
    
    guard let match = requestedDimension.range(of: regexPattern, options: .regularExpression) else {
        warnings.append(SwiftAdaptiveCardParseWarning(
            statusCode: .invalidDimensionSpecified,
            message: "Invalid dimension format: \(requestedDimension)"
        ))
        return nil
    }
    
    let numberString = String(requestedDimension[match])
    return Int(numberString) ?? {
        warnings.append(SwiftAdaptiveCardParseWarning(
            statusCode: .invalidDimensionSpecified,
            message: "Invalid number format: \(requestedDimension)"
        ))
        return nil
    }()
}

/// Determines whether an input string should be parsed for an explicit dimension.
private func shouldParseForExplicitDimension(_ input: String) -> Bool {
    guard !input.isEmpty else { return false }
    return input.first == "-" || input.first == "." || input.contains(where: { $0.isNumber }) && input.contains(where: { $0.isLetter || $0 == "." })
}

class SwiftWarningCollector {
    static var warnings: [SwiftAdaptiveCardParseWarning] = []
    
    static func add(_ newWarnings: [SwiftAdaptiveCardParseWarning]) {
        warnings.append(contentsOf: newWarnings)
    }
    
    static func getAndClearWarnings() -> [SwiftAdaptiveCardParseWarning] {
        let current = warnings
        warnings = []
        return current
    }
}

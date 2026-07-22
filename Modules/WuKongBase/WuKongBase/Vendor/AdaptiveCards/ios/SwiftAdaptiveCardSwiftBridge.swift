//
//  SwiftAdaptiveCardBridge.swift
//  AdaptiveCards
//
//  Created by Hugo Gonzalez on 3/3/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

import Foundation

public protocol Convertible {
    associatedtype Target
    func convert() -> Target
}

extension Array where Element: Convertible {
    func convert() -> [Element.Target] {
        return self.map { $0.convert() }
    }
}

@objcMembers
public class SwiftAdaptiveCardParseResult: NSObject {
    public var parseResult: SwiftParseResult?
    public var errors: [NSError]?
    public var warnings: [ACRParseWarning]?
}

@objcMembers
public class SwiftAdaptiveCardParser: NSObject {
    public static let main = SwiftAdaptiveCardParser()
    
    private var swiftParserEnabled = false
    
    // Toggle by ECS flag
    public static func setSwiftParserEnabled(_ isEnabled: Bool) {
        main.swiftParserEnabled = isEnabled
    }
    
    public static func isSwiftParserEnabled() -> Bool {
        return main.swiftParserEnabled
    }
    
    public static func parse(payload: String) -> SwiftAdaptiveCardParseResult {
        let result = SwiftAdaptiveCardParseResult()
        
        do {
            let parseResult = try SwiftAdaptiveCard.deserializeFromString(payload, version: "1.6")
            result.parseResult = parseResult
            result.warnings = parseResult.warnings.convert()
        } catch {
            // Capture the error instead of returning nil
            let nsError = error as NSError
            result.errors = [nsError]
            result.parseResult = nil
            result.warnings = []
        }
        
        return result
    }
}

// MARK: - ACRParseWarning
extension SwiftAdaptiveCardParseWarning: Convertible {
    public typealias Target = ACRParseWarning

    public func convert() -> ACRParseWarning {
        return .createWithStatusCode(getStatusCode().convert().rawValue, reason: getReason())
    }
}

extension SwiftWarningStatusCode: Convertible {
    public typealias Target = ACRWarningStatusCode

    public func convert() -> ACRWarningStatusCode {
        switch self {
        case .unknownElementType: .unknownElementType
        case .unknownActionElementType: .unknownActionElementType
        case .unknownPropertyOnElement: .unknownPropertyOnElement
        case .unknownEnumValue: .unknownEnumValue
        case .noRendererForType: .noRendererForType
        case .interactivityNotSupported: .interactivityNotSupported
        case .maxActionsExceeded: .maxActionsExceeded
        case .assetLoadFailed: .assetLoadFailed
        case .unsupportedSchemaVersion: .unsupportedSchemaVersion
        case .unsupportedMediaType: .unsupportedMediaType
        case .invalidMediaMix: .invalidMediaMix
        case .invalidColorFormat: .invalidColorFormat
        case .invalidDimensionSpecified: .invalidDimensionSpecified
        case .invalidLanguage: .invalidLanguage
        case .invalidValue: .invalidValue
        case .customWarning: .customWarning
        case .emptyLabelInRequiredInput: .unknownPropertyOnElement
        case .requiredPropertyMissing: .missingInputErrorMessage
        }
    }
}

// Swift subclass of ACRParseWarning
@objc public class ACRSwiftParseWarning: ACRParseWarning {
    // These properties will override the readonly properties from the parent
    private var _statusCode: ACRWarningStatusCode
    private var _reason: String
    
    @objc override public var statusCode: ACRWarningStatusCode {
        return _statusCode
    }
    
    @objc override public var reason: String {
        return _reason
    }
    
    @objc public init(statusCode: ACRWarningStatusCode, reason: String) {
        self._statusCode = statusCode
        self._reason = reason
        super.init()
    }
}

// Extension to add factory method to ACRParseWarning
@objc extension ACRParseWarning {
    // Factory method that creates and returns the Swift subclass
    @objc public class func createWithStatusCode(_ statusCode: UInt, reason: String) -> ACRParseWarning {
        return ACRSwiftParseWarning(
            statusCode: ACRWarningStatusCode(rawValue: statusCode) ?? .unknownElementType,
            reason: reason
        )
    }
}

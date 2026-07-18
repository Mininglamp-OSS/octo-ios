//
//  SwiftParseContext.swift
//  SwiftAdaptiveCards
//
//  Created by Hugo Gonzalez on 3/07/25.
//

import Foundation

/// Represents the context during parsing of an Adaptive Card, tracking hierarchy and element state.
public class SwiftParseContext {
    public var elementParserRegistration: SwiftElementParserRegistration?
    public var actionParserRegistration: ActionParserRegistration?
    public var warnings: [SwiftAdaptiveCardParseWarning] = []
    
    /// Keeps track of seen elements to detect ID collisions.
    private var elementIds: [String: SwiftInternalId] = [:]
    
    /// Stack used during parsing to track the hierarchy of elements.
    private var idStack: [(id: String, internalId: SwiftInternalId, isFallback: Bool)] = []
    
    /// Tracks container styles as they are nested.
    public var parentalContainerStyles: [SwiftContainerStyle] = []
    
    /// Tracks padding elements in the parse hierarchy.
    private var parentalPadding: [SwiftInternalId] = []
    
    /// Tracks bleed direction during parsing.
    private var parentalBleedDirection: [SwiftContainerBleedDirection] = []
    
    /// Determines if fallback to an ancestor element is possible.
    var canFallbackToAncestor: Bool = false
    
    /// The language setting for parsing.
    var language: String?

    // MARK: - Initializers
    
    public init() {
        // Create default element parser registration with built-in parsers
        self.elementParserRegistration = SwiftElementParserRegistration()
    }
    
    public init(elementParserRegistration: SwiftElementParserRegistration?, actionParserRegistration: ActionParserRegistration?) {
        self.elementParserRegistration = elementParserRegistration
        self.actionParserRegistration = actionParserRegistration
    }
    
    // MARK: - Hierarchy Management
    
    /// Push an element onto the parsing stack.
    func pushElement(idJsonProperty: String, internalId: SwiftInternalId, isFallback: Bool = false) {
        idStack.append((id: idJsonProperty, internalId: internalId, isFallback: isFallback))
    }
    
    /// Pop the last element off the parsing stack.
    func popElement() {
        _ = idStack.popLast()
    }
    
    /// Retrieve the nearest valid fallback ID in the hierarchy.
    func getNearestFallbackId(skipId: SwiftInternalId) -> SwiftInternalId? {
        return idStack.reversed().first { $0.internalId != skipId }?.internalId
    }
    
    // MARK: - Style and Context Management
    
    func setLanguage(_ value: String) {
        language = value
    }
    
    func getLanguage() -> String? {
        return language
    }
    
    func setParentalContainerStyle(_ style: SwiftContainerStyle) {
        parentalContainerStyles.append(style)
    }
    
    func getParentalContainerStyle() -> SwiftContainerStyle? {
        return parentalContainerStyles.last
    }
    
    func saveContextForStyledCollectionElement(_ element: SwiftStyledCollectionElement) {
        print("Saving context for element with style: \(element.style)")
        parentalContainerStyles.append(element.style)
        
        // Only add to padding parents if this element has padding
        if element.hasPadding {
            print("Adding padding parent with ID: \(element.internalId)")
            parentalPadding.append(element.internalId)
        }
        
        if element.hasBleed && element.hasPadding {
            parentalBleedDirection.append(.bleedAll)
        } else {
            parentalBleedDirection.append(.bleedRestricted)
        }
        
        print("Current padding parents: \(parentalPadding)")
    }
    
    /// Returns the most recently pushed container style, or nil if none exists.
    var parentalContainerStyle: SwiftContainerStyle? {
        return self.parentalContainerStyles.last
    }
    
    func restoreContextForStyledCollectionElement(_ current: SwiftStyledCollectionElement) {
            _ = parentalPadding.popLast()
            _ = parentalContainerStyles.popLast()
            _ = parentalBleedDirection.popLast()
        }
        
    func pushBleedDirection(_ direction: SwiftContainerBleedDirection) {
        parentalBleedDirection.append(direction)
    }
    
    func popBleedDirection() {
        _ = parentalBleedDirection.popLast()
    }
    
    var bleedDirection: SwiftContainerBleedDirection {
        return parentalBleedDirection.last ?? .bleedAll
    }
    
    func paddingParentInternalId() -> SwiftInternalId? {
        return parentalPadding.last
    }
    
    // Add a helper method to check if a style requires padding
    func doesStyleRequirePadding(_ style: SwiftContainerStyle) -> Bool {
        guard let parentStyle = parentalContainerStyle else {
            return false
        }
        return style != .none && style != parentStyle
    }
    
    func printStyleStack() {
        print("Current style stack: \(parentalContainerStyles)")
    }
}

public struct SwiftAdaptiveCardParseWarning: Codable {
    public let statusCode: SwiftWarningStatusCode
    public let message: String

    public init(statusCode: SwiftWarningStatusCode, message: String) {
        self.statusCode = statusCode
        self.message = message
    }

    public func getStatusCode() -> SwiftWarningStatusCode {
        return statusCode
    }

    public func getReason() -> String {
        return message
    }
}

/// Represents an error encountered while parsing an Adaptive Card.
public struct SwiftAdaptiveCardParseException: Error {
    public let statusCode: SwiftErrorStatusCode
    public let message: String
    
    public init(statusCode: SwiftErrorStatusCode, message: String) {
        self.statusCode = statusCode
        self.message = message
    }
    
    // Added to satisfy tests:
    public func what() -> String {
        return message
    }
    
    public func getStatusCode() -> SwiftErrorStatusCode {
        return statusCode
    }
    
    public func getReason() -> String {
        return message
    }
}

extension SwiftAdaptiveCardParseException: LocalizedError {
    public var errorDescription: String? {
        return message
    }
}

/// A Swift version of ParseResult, which wraps an AdaptiveCard plus any warnings from parsing.
public class SwiftParseResult {
    
    private let mAdaptiveCard: SwiftAdaptiveCard
    private let mWarnings: [SwiftAdaptiveCardParseWarning]
    
    /// Creates a new ParseResult containing the parsed AdaptiveCard and any parse warnings.
    public init(adaptiveCard: SwiftAdaptiveCard, warnings: [SwiftAdaptiveCardParseWarning]) {
        self.mAdaptiveCard = adaptiveCard
        self.mWarnings = warnings
    }
    
    /// Returns the parsed AdaptiveCard.
    public func getAdaptiveCard() -> SwiftAdaptiveCard {
        return mAdaptiveCard
    }
    
    /// Returns any warnings that occurred during parsing.
    public func getWarnings() -> [SwiftAdaptiveCardParseWarning] {
        return mWarnings
    }
    
    /// For convenience, you can also expose them as properties:
    public var adaptiveCard: SwiftAdaptiveCard {
        return mAdaptiveCard
    }
    
    public var warnings: [SwiftAdaptiveCardParseWarning] {
        return mWarnings
    }
}

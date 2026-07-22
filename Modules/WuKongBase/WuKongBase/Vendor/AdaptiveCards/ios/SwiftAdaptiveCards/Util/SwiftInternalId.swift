//
//  SwiftInternalId.swift
//  SwiftAdaptiveCards
//
//  Created by Hugo Gonzalez on 3/07/25.
//

import Foundation

/// Represents a unique identifier for elements during deserialization.
public struct SwiftInternalId: Hashable, Codable {
    private static var currentInternalId: UInt = 0
    private let internalId: UInt

    /// Creates a new InternalId with the next available unique identifier.
    static func next() -> SwiftInternalId {
        currentInternalId += 1
        return SwiftInternalId(id: currentInternalId)
    }

    /// Retrieves the current InternalId without incrementing.
    static func current() -> SwiftInternalId {
        return SwiftInternalId(id: currentInternalId)
    }

    /// Represents an invalid internal ID.
    static let invalid: SwiftInternalId = SwiftInternalId(id: 0)

    /// Returns the hash value for this internal ID.
    func hashValue() -> UInt {
        return internalId
    }

    // MARK: - Equatable & Hashable
    public static func == (lhs: SwiftInternalId, rhs: SwiftInternalId) -> Bool {
        return lhs.internalId == rhs.internalId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(internalId)
    }

    // Private initializer to control ID assignment
    private init(id: UInt) {
        self.internalId = id
    }
}

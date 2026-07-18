//
//  SwiftFeatureRegistration.swift
//  SwiftAdaptiveCards
//
//  Created by Hugo Gonzalez on 3/07/25.
//

import Foundation

struct SwiftFeatureRegistration {
    private var supportedFeatures: [String: String]

    init() {
        self.supportedFeatures = [SwiftFeatureRegistration.adaptiveCardsFeature: SwiftFeatureRegistration.sharedModelVersion]
    }

    mutating func addFeature(featureName: String, featureVersion: String) throws {
        // Validate the version string. We only support "*" or a semantic version string (e.g., "1.0", "1.2.3.4")
        if featureVersion != "*" {
            _ = try SwiftSemanticVersion(featureVersion) // Throws if invalid
        }

        if let existingVersion = supportedFeatures[featureName] {
            if existingVersion != featureVersion {
                throw SwiftAdaptiveCardParseException(
                    statusCode: .invalidPropertyValue,
                    message: "Attempting to add a feature with a differing version"
                )
            }
        } else {
            supportedFeatures[featureName] = featureVersion
        }
    }

    mutating func removeFeature(featureName: String) throws {
        if featureName == SwiftFeatureRegistration.adaptiveCardsFeature {
            throw SwiftAdaptiveCardParseException(
                statusCode: .unsupportedParserOverride,
                message: "Removing the Adaptive Cards feature is unsupported"
            )
        }
        supportedFeatures.removeValue(forKey: featureName)
    }

    func getAdaptiveCardsVersion() throws -> SwiftSemanticVersion {
        return try SwiftSemanticVersion(getFeatureVersion(featureName: SwiftFeatureRegistration.adaptiveCardsFeature))
    }

    func getFeatureVersion(featureName: String) -> String {
        return supportedFeatures[featureName] ?? ""
    }

    // Static Constants
    static let adaptiveCardsFeature = "adaptiveCards"
    static let sharedModelVersion = "1.0.0" // Placeholder for the actual shared model version
}

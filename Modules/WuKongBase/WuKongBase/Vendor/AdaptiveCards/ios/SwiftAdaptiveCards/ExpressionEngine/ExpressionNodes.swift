//
//  ExpressionNodes.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - ExpressionNode

public class ExpressionNode: EvaluationNode {

    private var nodes: [EvaluationNode] = []
    
    // Made private with public getter/setter for better encapsulation
    private var _allowNull = true
    
    public var allowNull: Bool {
        get { return _allowNull }
        set { _allowNull = newValue }
    }
    
    private let operatorPriorityGroups: [[BinaryOperatorType]] = [
        [.division, .multiplication],
        [.subtraction, .addition],
        [.equality, .inequality, .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual, .logicalAnd, .logicalOr, .inclusion]
    ]
    
    public init() {}
    
    // Builder methods for controlled access
    public func addNode(_ node: EvaluationNode) {
        nodes.append(node)
    }
    
    public func addNodes(_ newNodes: [EvaluationNode]) {
        nodes.append(contentsOf: newNodes)
    }
    
    public var nodeCount: Int {
        return nodes.count
    }
    
    public func evaluate(context: EvaluationContext) async throws -> EvaluationResult {
        if nodes.count == 1 {
            return try await nodes[0].evaluate(context: context)
        }
        
        var nodesCopy = nodes
        
        for priorityGroup in operatorPriorityGroups {
            var i = 0
            while i < nodesCopy.count {
                if let node = nodesCopy[i] as? BinaryOperatorNode,
                   priorityGroup.contains(node.operatorType) {
                    
                    let leftResult = try await nodesCopy[i - 1].evaluate(context: context)
                    let rightResult = try await nodesCopy[i + 1].evaluate(context: context)
                    
                    let result = try await node.evaluate(context: context,
                                                   left: ExpressionUtilities.assertValueType(value: leftResult),
                                                   right: ExpressionUtilities.assertValueType(value: rightResult))
                    
                    nodesCopy.removeSubrange((i-1)...(i+1))
                    nodesCopy.insert(LiteralNode(value: result), at: i - 1)
                    
                    i -= 1
                }
                i += 1
            }
        }
        return try await nodesCopy[0].evaluate(context: context)
    }
}

// MARK: - IdentifierNode

public class IdentifierNode: EvaluationNode {
    // Made internal - accessed by PathNode.getIdentifierNames() and parser
    internal var identifier: String?

    public init(identifier: String? = nil) {
        self.identifier = identifier
    }

    public func evaluate(context: EvaluationContext) async throws -> EvaluationResult {
        guard let identifier = identifier else { return nil }

        // First check variable scope using the actor's public method
        if let value = await context.getVariable(identifier) {
            return value
        }

        // For simple identifiers, check context root data
        if let contextData = await context.root as? [String: Any],
           let value = contextData[identifier] {
            return value
        }

        // Check current data context as well
        if let contextData = await context.currentDataContext as? [String: Any],
           let value = contextData[identifier] {
            return value
        }

        // If not found in any scope, throw an error for undefined variable
        throw EvaluationError.undefinedVariable("Variable '\(identifier)' is not defined")
    }
}

// MARK: - IndexerNode

public class IndexerNode: EvaluationNode {
    // Made internal - accessed by parser and PathNode evaluation
    internal var index: ExpressionNode?
    
    public init(index: ExpressionNode? = nil) {
        self.index = index
    }
    
    public func evaluate(context: EvaluationContext) async throws -> EvaluationResult {
        return try await index?.evaluate(context: context)
    }
}

// MARK: - FunctionCallNode

public class FunctionCallNode: EvaluationNode {
    public let functionName: String
    private var parameters: [ExpressionNode] = []
    
    public init(functionName: String) {
        self.functionName = functionName
    }
    
    public func addParameter(_ parameter: ExpressionNode) {
        parameters.append(parameter)
    }
    
    public func addParameters(_ newParameters: [ExpressionNode]) {
        parameters.append(contentsOf: newParameters)
    }
    
    public var parameterCount: Int {
        return parameters.count
    }
    
    public func evaluate(context: EvaluationContext) async throws -> EvaluationResult {
        return try await context.executeFunction(name: functionName, params: parameters)
    }
}

// MARK: - LiteralNode

public class LiteralNode: EvaluationNode {
    public let value: Any?
    
    public init(value: Any?) {
        self.value = value
    }
    
    public func evaluate(context: EvaluationContext) async throws -> EvaluationResult {
        return value
    }
}

// MARK: - ArrayNode

public class ArrayNode: EvaluationNode {
    private var items: [ExpressionNode] = []
    
    public init() {}
    
    public func addItem(_ item: ExpressionNode) {
        items.append(item)
    }
    
    public func addItems(_ newItems: [ExpressionNode]) {
        items.append(contentsOf: newItems)
    }
    
    public var itemCount: Int {
        return items.count
    }
    
    public func evaluate(context: EvaluationContext) async throws -> EvaluationResult {
        var results: [Any?] = []
        for item in items {
            let result = try await item.evaluate(context: context)
            results.append(result)
        }
        return results
    }
}

// MARK: - PathNode

public class PathNode: EvaluationNode {
    private var parts: [EvaluationNode] = []

    public init() {}
    
    public func addPart(_ part: EvaluationNode) {
        parts.append(part)
    }
    
    public func addParts(_ newParts: [EvaluationNode]) {
        parts.append(contentsOf: newParts)
    }
    
    public var partCount: Int {
        return parts.count
    }
    
    public var isEmpty: Bool {
        return parts.isEmpty
    }
    
    // Method needed for parser to extract function names
    public func getIdentifierNames() -> [String] {
        return parts.compactMap { ($0 as? IdentifierNode)?.identifier }
    }
    
    // Method needed for parser to clear parts when building function calls
    public func clearParts() {
        parts.removeAll()
    }

    public func evaluate(context: EvaluationContext) async throws -> EvaluationResult {
        guard !parts.isEmpty else { return nil }

        // Evaluate the first part of the path to get the base object.
        var currentResult = try await parts[0].evaluate(context: context)

        // Process the rest of the parts for property or array access.
        for i in 1..<parts.count {
            let part = parts[i]
            
            if let identifierNode = part as? IdentifierNode, let key = identifierNode.identifier {
                // Handle property access (e.g., .name)
                guard let dict = currentResult as? [String: Any] else {
                    throw EvaluationError.invalidPath("Cannot access property '\(key)' on a non-dictionary type. Current value is \(String(describing: currentResult)).")
                }
                currentResult = dict[key]
            } else if let indexerNode = part as? IndexerNode {
                // Handle array access (e.g., [1])
                guard let array = currentResult as? [Any] else {
                    throw EvaluationError.invalidPath("Cannot apply indexer to a non-array type. Current value is \(String(describing: currentResult)).")
                }
                
                // Evaluate the expression inside the indexer to get the index value.
                let indexValue = try await indexerNode.evaluate(context: context)
                
                var index: Int?
                if let intValue = indexValue as? Int {
                    index = intValue
                } else if let doubleValue = indexValue as? Double {
                    // Allow doubles if they can be represented as an Int without loss of precision.
                    if doubleValue == floor(doubleValue) {
                        index = Int(doubleValue)
                    }
                }

                guard let finalIndex = index else {
                    throw EvaluationError.invalidPath("Array index must be an integer, but got '\(String(describing: indexValue))'.")
                }
                
                guard finalIndex >= 0 && finalIndex < array.count else {
                    // Return nil for out-of-bounds access, as per Adaptive Card expression language spec.
                    currentResult = nil
                    break
                }
                currentResult = array[finalIndex]
            } else {
                // This case should not be hit with a validly parsed path.
                throw EvaluationError.invalidPath("Invalid path component encountered: \(type(of: part)).")
            }
        }
        return currentResult
    }
}

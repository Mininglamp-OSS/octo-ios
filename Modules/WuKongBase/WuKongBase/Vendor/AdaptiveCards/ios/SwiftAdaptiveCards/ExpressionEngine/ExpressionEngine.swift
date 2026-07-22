//
//  ExpressionEngine.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - Concrete Implementation

public class ExpressionEngine: ExpressionEngineProtocol {
    
    // MARK: - Properties
    
    public let version = "2.0.0"
    public let buildDate = "2025-08-25"
    
    // MARK: - Dependencies
    
    private let cacheManager: CacheManaging?
    
    // MARK: - Initialization
    
    /// Default initializer without caching
    public init() {
        self.cacheManager = nil
    }
    
    /// Dependency injection initializer with cache manager
    public init(cacheManager: CacheManaging) {
        self.cacheManager = cacheManager
    }
    
    /// Convenience initializer with default cache manager
    public init(enableCaching: Bool) {
        self.cacheManager = enableCaching ? CacheManager() : nil
    }
    
    // MARK: - ExpressionEvaluating
    
    /// Evaluate a simple expression string
    /// - Parameters:
    ///   - expression: The expression string to evaluate
    ///   - data: Optional data context
    /// - Returns: The evaluation result
    public func evaluate(_ expression: String, with data: Any? = nil) async -> EvaluationResult {
        do {
            let expressionObj = try createExpression(expression, allowAssignment: false)
            let context = await data != nil ? EvaluationContext(config: EvaluationContextConfig(root: data)) : nil
            let result = await expressionObj.evaluateResult(context: context)
            switch result {
            case .success(let value):
                return value
            case .failure:
                return nil
            }
        } catch {
            return nil
        }
    }
    
    /// Evaluate a binding template
    /// - Parameters:
    ///   - template: The binding template string (e.g., "${user.name}")
    ///   - data: Optional data context
    /// - Returns: The evaluation result
    public func evaluateBinding(_ template: String, with data: Any? = nil) async -> EvaluationResult {
        do {
            let binding = try createBinding(template)
            let context = await data != nil ? EvaluationContext(config: EvaluationContextConfig(root: data)) : nil
            return try await binding.evaluate(context: context)
        } catch {
            return nil
        }
    }
    
    // MARK: - ExpressionCreating
    
    /// Create a new expression with options
    /// - Parameters:
    ///   - expression: The expression string
    ///   - allowAssignment: Whether to allow variable assignments
    /// - Returns: A configured Expression instance
    public func createExpression(_ expression: String, allowAssignment: Bool = false) throws -> Expression {
        let options = ExpressionOptions(allowAssignment: allowAssignment)
        return try Expression(expressionString: expression, options: options)
    }
    
    /// Create a new binding template
    /// - Parameter template: The binding template string
    /// - Returns: A configured Binding instance
    public func createBinding(_ template: String) throws -> Binding {
        return try Binding(expressionString: template)
    }
    
    // MARK: - ContextManaging
    
    /// Create a basic evaluation context
    /// - Parameter data: Optional root data object
    /// - Returns: A configured EvaluationContext
    public func createContext(with data: Any? = nil) async -> EvaluationContext {
        let config = EvaluationContextConfig(root: data)
        return await EvaluationContext(config: config)
    }
    
    /// Create a default evaluation context with built-in functions
    /// - Parameter data: Optional root data object
    /// - Returns: A configured EvaluationContext
    public func createDefaultContext(with data: Any? = nil) async -> EvaluationContext {
        let config = EvaluationContextConfig(
            groupId: "default",
            root: data,
            functions: [defaultDeclaration()]
        )
        return await EvaluationContext(config: config)
    }
    
    // MARK: - ObjCBridging
    
    /// Bridge function for Objective-C compatibility
    public func callEvaluationFromObjC(expression: Expression, context: EvaluationContext? = nil) async -> EvaluationResultWrapper {
        let result = await expression.evaluateResult(context: context)
        switch result {
        case .success(let value):
            return EvaluationResultWrapper(value: value)
        case .failure:
            return EvaluationResultWrapper(value: nil)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Sample async authorization function
    private func defaultHandler() async -> Bool {
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        } catch {
            return false
        }
        let val = false
        return val
    }
    
    /// Create function declaration for authorization
    private func defaultDeclaration() -> FunctionDeclaration {
        return FunctionDeclaration(
            name: "defaultHandler",
            cacheResultFor: nil,
            callback: { _ in
                return await self.defaultHandler()
            }
        )
    }
}

// MARK: - Factory for Creating Engine Instances

public struct ExpressionEngineFactory {
    
    /// Create a standard expression engine instance without caching
    public static func createEngine() -> ExpressionEngineProtocol {
        return ExpressionEngine()
    }
    
    /// Create an engine instance with caching enabled
    public static func createEngineWithCaching() -> ExpressionEngineProtocol {
        return ExpressionEngine(enableCaching: true)
    }
    
    /// Create an engine instance with custom cache manager
    public static func createEngine(cacheManager: CacheManaging) -> ExpressionEngineProtocol {
        return ExpressionEngine(cacheManager: cacheManager)
    }
    
    /// Create an engine instance with custom configuration
    public static func createEngine(with configuration: EngineConfiguration) -> ExpressionEngineProtocol {
        // Currently only enableCaching is implemented
        
        if configuration.isEnableCaching() {
            let cacheManager = CacheManager()
            return ExpressionEngine(cacheManager: cacheManager)
        } else {
            return ExpressionEngine()
        }
    }
}

// MARK: - Configuration Support

public struct EngineConfiguration {
    private let _enableCaching: Bool
    private let _defaultTimeout: TimeInterval
    private let _customFunctions: [FunctionDeclaration]
    
    public init(enableCaching: Bool = true, defaultTimeout: TimeInterval = 30.0, customFunctions: [FunctionDeclaration] = []) {
        self._enableCaching = enableCaching
        self._defaultTimeout = defaultTimeout
        self._customFunctions = customFunctions
    }
    
    // MARK: - Public Getter Functions
    
    /// Returns whether caching is enabled for the expression engine
    /// - Returns: Boolean indicating if caching is enabled
    public func isEnableCaching() -> Bool {
        return _enableCaching
    }
    
    /// Returns the default timeout for expression evaluation operations
    /// - Returns: TimeInterval representing the default timeout in seconds
    public func getDefaultTimeout() -> TimeInterval {
        return _defaultTimeout
    }
    
    /// Returns the custom functions to register with the expression engine
    /// - Returns: Array of FunctionDeclaration objects
    public func getCustomFunctions() -> [FunctionDeclaration] {
        return _customFunctions
    }
}

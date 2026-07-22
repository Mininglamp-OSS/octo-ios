//
//  EvaluationContext.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//


import Foundation

// MARK: - Thread-Safe Cache Manager Actor

actor FunctionCallCacheManager {
    static let shared = FunctionCallCacheManager()
    
    private var cacheMap: [String: FunctionCallCache] = [:]
    
    private init() {} // Singleton
    
    func getCache(for groupId: String) -> FunctionCallCache {
        if let existingCache = cacheMap[groupId] {
            return existingCache
        }
        
        let newCache = FunctionCallCache()
        cacheMap[groupId] = newCache
        return newCache
    }
    
    func setCache(for groupId: String, cache: FunctionCallCache) {
        cacheMap[groupId] = cache
    }
    
    func removeCache(for groupId: String) {
        cacheMap[groupId] = nil
    }
    
    func clearAllCaches() {
        cacheMap.removeAll()
    }
}

// MARK: - Modern Actor-Based EvaluationContext

public actor EvaluationContext {
    // MARK: - Properties
    
    // Immutable properties
    public let groupId: String?
    public let root: Any?
    
    // Mutable state protected by actor
    private var stateStack: [EvaluationContextState] = []
    private var functions: [String: FunctionDeclaration] = [:]
    private var functionCallCache: FunctionCallCache
    private var data: Any?
    private var variableScope: [String: Any?] = [:]
    private var index: Int = 0
    
    // Dependencies
    private let builtInFunctions: FunctionProvider
    
    // MARK: - Initialization
    
    public init(
        config: EvaluationContextConfig? = nil,
        builtInFunctions: FunctionProvider = BuiltInFunctions()
    ) async {
        self.groupId = config?.groupId
        self.root = config?.root
        self.data = nil
        self.builtInFunctions = builtInFunctions
        
        // Register custom functions
        if let configFunctions = config?.functions {
            for function in configFunctions {
                self.functions[function.name] = function
            }
        }
        
        // Get or create cache using actor-based manager
        if let groupId = groupId {
            self.functionCallCache = await FunctionCallCacheManager.shared.getCache(for: groupId)
        } else {
            self.functionCallCache = FunctionCallCache()
        }
    }
    
    // MARK: - Public API
    
    public var currentDataContext: Any? {
        return data ?? root
    }
    
    // MARK: - Internal API (Engine implementation details - restrict access)
    
    internal func getCurrentData() -> Any? {
        return data
    }
    
    internal func setCurrentData(_ newData: Any?) {
        data = newData
    }
    
    internal func getCurrentIndex() -> Int {
        return index
    }
    
    internal func setCurrentIndex(_ newIndex: Int) {
        index = newIndex
    }
    
    // MARK: - Variable Management
    
    public func getVariable(_ name: String) -> Any? {
        guard let val = variableScope[name] else {
            return nil
        }
        return val
    }
    
    public func setVariable(_ name: String, value: Any?) {
        variableScope[name] = value
    }
    
    public subscript(variable: String) -> Any? {
        get {
            guard let ret = variableScope[variable] else {
                return nil
            }
            return ret
        }
        set { variableScope[variable] = newValue }
    }
    
    // MARK: - Internal accessors for engine use only
    
    internal var allVariables: [String: Any?] {
        return variableScope
    }
    
    // MARK: - Context Management
    
    public func clone() async -> EvaluationContext {
        let config = EvaluationContextConfig(
            groupId: self.groupId,
            root: self.root,
            functions: Array(self.functions.values)
        )
        return await EvaluationContext(config: config, builtInFunctions: builtInFunctions)
    }
    
    internal func registerFunctions(_ functions: FunctionDeclaration...) {
        for function in functions where self.functions[function.name] == nil {
            self.functions[function.name] = function
        }
    }
    
    // MARK: - Function Management (Public API for function access)
    
    public func getFunction(name: String) -> FunctionDeclaration? {
        // Check custom functions first
        if let customFunction = functions[name] {
            return customFunction
        }
        
        // Fall back to built-in functions
        return builtInFunctions.getFunction(name: name)
    }
    
    // MARK: - Internal Function Management (for engine use)
    
    internal func getAllFunctions() -> [String: FunctionDeclaration] {
        var allFunctions = builtInFunctions.functions
        
        // Add custom functions (they override built-ins)
        for (name, function) in functions {
            allFunctions[name] = function
        }
        
        return allFunctions
    }
    
    // MARK: - Function Execution
    
    public func executeFunction(name: String, params: [ExpressionNode]) async throws -> EvaluationResult {
        guard let declaration = getFunction(name: name) else {
            throw EvaluationError.unknownFunction("Unknown function \"\(name)\"")
        }
        
        var evaluatedParams: [Any?] = []
        for param in params {
            let result = try await param.evaluate(context: self)
            evaluatedParams.append(result)
        }
        
        return await functionCallCache.callFunction(declaration: declaration, params: evaluatedParams)
    }
    
    // MARK: - Internal State Management (for expression evaluation)
    
    internal func saveState() {
        stateStack.append(EvaluationContextState(data: data, index: index))
    }
    
    internal func restoreLastState() throws {
        guard let savedState = stateStack.popLast() else {
            throw EvaluationError.noStateToRestore
        }
        data = savedState.data
        index = savedState.index
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Clean up cache when context is deallocated
        if let groupId = groupId {
            Task.detached { [groupId] in
                await FunctionCallCacheManager.shared.removeCache(for: groupId)
            }
        }
    }
}

// MARK: - FunctionProvider Conformance via Wrapper

public class EvaluationContextWrapper: FunctionProvider {
    private let actorContext: EvaluationContext
    private let cachedFunctions: [String: FunctionDeclaration]
    
    public init(_ actorContext: EvaluationContext) async {
        self.actorContext = actorContext
        self.cachedFunctions = await actorContext.getAllFunctions()
    }
    
    public var functions: [String: FunctionDeclaration] {
        return cachedFunctions
    }
    
    public func getFunction(name: String) -> FunctionDeclaration? {
        return cachedFunctions[name]
    }
}

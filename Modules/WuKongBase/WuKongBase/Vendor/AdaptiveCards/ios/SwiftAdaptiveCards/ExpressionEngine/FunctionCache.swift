//
//  FunctionCache.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - Cache Management Protocol

public protocol CacheManaging: Actor {
    func callFunction(declaration: FunctionDeclaration, params: [EvaluationResult]?) async -> EvaluationResult
    func configureCaching(for functionName: String, configuration: CacheConfiguration)
    func clearAllCaches() async
    func clearCache(for functionName: String) async
    func getCacheStatistics() async -> CacheStatistics
    var cacheEvents: AsyncStream<CacheEvent> { get }
}

// MARK: - CachedFunctionCall Actor

internal actor CachedFunctionCall {
    private let declaration: FunctionDeclaration
    private let params: [EvaluationResult]?
    
    private var timeStamp: Int64?
    private var cachedResult: EvaluationResult?
    
    internal init(declaration: FunctionDeclaration, params: [EvaluationResult]?) {
        self.declaration = declaration
        self.params = params
    }
    
    // Controlled getter for declaration name
    internal var declarationName: String {
        return declaration.name
    }
    
    // Controlled getter for params
    internal var paramsList: [EvaluationResult]? {
        return params
    }
    
    internal func getCachedResult() -> EvaluationResult? {
        return cachedResult
    }
    
    internal func setCachedResult(_ result: EvaluationResult) {
        self.cachedResult = result
        self.timeStamp = Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    internal func isOutdated() -> Bool {
        guard let cacheResultFor = declaration.cacheResultFor else { return true }
        guard let ts = timeStamp else { return false }
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        return (currentTime - ts) > cacheResultFor
    }
    
    // Custom equality for actor - now uses controlled access
    internal func isEqual(to other: CachedFunctionCall) async -> Bool {
        let otherDeclarationName = await other.declarationName
        let otherParams = await other.paramsList
        
        return self.declaration.name == otherDeclarationName &&
               areParamsEqual(self.params, otherParams)
    }
    
    private func areParamsEqual(_ lhs: [EvaluationResult]?, _ rhs: [EvaluationResult]?) -> Bool {
        if lhs == nil && rhs == nil { return true }
        if lhs == nil || rhs == nil { return false }
        
        guard let lhsArray = lhs, let rhsArray = rhs else { return false }
        guard lhsArray.count == rhsArray.count else { return false }
        
        for (index, lhsElement) in lhsArray.enumerated() {
            let rhsElement = rhsArray[index]
            if !ExpressionUtilities.areEqual(lhsElement, rhsElement) {
                return false
            }
        }
        return true
    }
}

// MARK: - FunctionCallCache Actor

public actor FunctionCallCache {
    private var callCache: [String: CachedFunctionCall] = [:]
    private var executingKeys: Set<String> = []
    
    public init() {}
    
    public func callFunction(declaration: FunctionDeclaration, params: [EvaluationResult]?) async -> EvaluationResult {
        let cacheKey = generateCacheKey(declaration: declaration, params: params)
        
        // Clean up outdated calls first
        await cleanupOutdatedCalls(for: declaration.name)
        
        // Check for existing cached result
        if let existingCall = callCache[cacheKey] {
            let isOutdated = await existingCall.isOutdated()
            if !isOutdated {
                if let cachedResult = await existingCall.getCachedResult() {
                    return cachedResult
                }
            } else {
                // Remove outdated cache entry
                callCache.removeValue(forKey: cacheKey)
            }
        }
        
        // Wait if another execution is in progress
        while executingKeys.contains(cacheKey) {
            await Task.yield() // Give other tasks a chance to complete
            
            // Check cache again after yielding - another task might have completed
            if let existingCall = callCache[cacheKey] {
                let isOutdated = await existingCall.isOutdated()
                if !isOutdated, let cachedResult = await existingCall.getCachedResult() {
                    return cachedResult
                }
            }
        }
        
        // Mark as executing
        executingKeys.insert(cacheKey)
        
        // Execute function directly
        let result: EvaluationResult
        do {
            result = try await declaration.callback(params ?? [])
        } catch {
            executingKeys.remove(cacheKey)
            return nil
        }
        
        // Cache successful result
        if let result = result {
            let cachedCall = CachedFunctionCall(declaration: declaration, params: params)
            await cachedCall.setCachedResult(result)
            callCache[cacheKey] = cachedCall
        }
        
        // Mark as no longer executing
        executingKeys.remove(cacheKey)
        
        return result
    }
    
    private func generateCacheKey(declaration: FunctionDeclaration, params: [EvaluationResult]?) -> String {
        let paramsString = params?.map { String(describing: $0) }.joined(separator: ",") ?? ""
        return "\(declaration.name)(\(paramsString))"
    }
    
    private func cleanupOutdatedCalls(for functionName: String) async {
        var keysToRemove: [String] = []
        
        for (key, cachedCall) in callCache {
            let callDeclarationName = await cachedCall.declarationName
            let isOutdated = await cachedCall.isOutdated()
            
            if callDeclarationName == functionName && isOutdated {
                keysToRemove.append(key)
            }
        }
        
        for key in keysToRemove {
            callCache.removeValue(forKey: key)
        }
    }
    
    public func clearCache() {
        callCache.removeAll()
        executingKeys.removeAll()
    }
    
    public func clearCache(for functionName: String) {
        var keysToRemove: [String] = []
        
        for (key, _) in callCache {
            if key.hasPrefix("\(functionName)(") {
                keysToRemove.append(key)
            }
        }
        
        for key in keysToRemove {
            callCache.removeValue(forKey: key)
        }
        
        // Remove from executing keys as well
        executingKeys = executingKeys.filter { !$0.hasPrefix("\(functionName)(") }
    }
    
    public func getCacheStats() async -> [String: Int] {
        var stats: [String: Int] = [:]
        
        for (_, cachedCall) in callCache {
            let functionName = await cachedCall.declarationName
            stats[functionName, default: 0] += 1
        }
        
        return stats
    }
}

// MARK: - Thread-Safe Cache Manager implementing CacheManaging

public actor CacheManager: CacheManaging {
    private let functionCache = FunctionCallCache()
    private var cacheConfigurations: [String: CacheConfiguration] = [:]
    
    // AsyncStream for cache events
    private let (cacheEventsStream, cacheEventsContinuation) = AsyncStream<CacheEvent>.makeStream()
    
    public func callFunction(declaration: FunctionDeclaration, params: [EvaluationResult]?) async -> EvaluationResult {
        let result = await functionCache.callFunction(declaration: declaration, params: params)
        
        // Only emit events for successful results
        if let result = result {
            let paramsDescription = params?.compactMap { $0 as? String }
            let resultDescription = result as? String ?? String(describing: result)
            
            cacheEventsContinuation.yield(CacheEvent.functionCalled(
                functionName: declaration.name,
                params: paramsDescription,
                resultDescription: resultDescription
            ))
        }
        
        return result
    }
    
    public func configureCaching(for functionName: String, configuration: CacheConfiguration) {
        cacheConfigurations[functionName] = configuration
        cacheEventsContinuation.yield(CacheEvent.configurationChanged(functionName: functionName, configuration: configuration))
    }
    
    public func clearAllCaches() async {
        await functionCache.clearCache()
        cacheEventsContinuation.yield(CacheEvent.cacheCleared(functionName: nil))
    }
    
    public func clearCache(for functionName: String) async {
        await functionCache.clearCache(for: functionName)
        cacheEventsContinuation.yield(CacheEvent.cacheCleared(functionName: functionName))
    }
    
    public func getCacheStatistics() async -> CacheStatistics {
        let stats = await functionCache.getCacheStats()
        return CacheStatistics(
            functionCounts: stats,
            totalCachedFunctions: stats.values.reduce(0, +),
            configurations: cacheConfigurations
        )
    }
    
    // Additional getter methods for better encapsulation
    public func getCacheConfiguration(for functionName: String) -> CacheConfiguration? {
        return cacheConfigurations[functionName]
    }
    
    public func getAllCacheConfigurations() -> [String: CacheConfiguration] {
        return cacheConfigurations
    }
    
    public func hasCachedFunction(_ functionName: String) async -> Bool {
        let stats = await functionCache.getCacheStats()
        return stats[functionName] != nil && stats[functionName] ?? 0 > 0
    }
    
    // Expose cache events as AsyncStream
    public var cacheEvents: AsyncStream<CacheEvent> {
        return cacheEventsStream
    }
}

// MARK: - Cache Events

public enum CacheEvent: Sendable {
    case functionCalled(functionName: String, params: [String]?, resultDescription: String)
    case configurationChanged(functionName: String, configuration: CacheConfiguration)
    case cacheCleared(functionName: String?)
}

// MARK: - Supporting Types

public struct CacheConfiguration: Sendable {
    private let _maxCacheSize: Int
    private let _defaultTTL: TimeInterval
    private let _enableCleanup: Bool
    
    // Public getters for controlled access
    public var maxCacheSize: Int { _maxCacheSize }
    public var defaultTTL: TimeInterval { _defaultTTL }
    public var enableCleanup: Bool { _enableCleanup }
    
    public init(maxCacheSize: Int = 100, defaultTTL: TimeInterval = 300, enableCleanup: Bool = true) {
        self._maxCacheSize = maxCacheSize
        self._defaultTTL = defaultTTL
        self._enableCleanup = enableCleanup
    }
    
    // Factory method for creating modified configurations
    public func with(maxCacheSize: Int? = nil, defaultTTL: TimeInterval? = nil, enableCleanup: Bool? = nil) -> CacheConfiguration {
        return CacheConfiguration(
            maxCacheSize: maxCacheSize ?? self._maxCacheSize,
            defaultTTL: defaultTTL ?? self._defaultTTL,
            enableCleanup: enableCleanup ?? self._enableCleanup
        )
    }
}

public struct CacheStatistics: Sendable {
    private let _functionCounts: [String: Int]
    private let _totalCachedFunctions: Int
    private let _configurations: [String: CacheConfiguration]
    
    // Public getters for controlled access
    public var functionCounts: [String: Int] { _functionCounts }
    public var totalCachedFunctions: Int { _totalCachedFunctions }
    public var configurations: [String: CacheConfiguration] { _configurations }
    
    public init(functionCounts: [String: Int], totalCachedFunctions: Int, configurations: [String: CacheConfiguration]) {
        self._functionCounts = functionCounts
        self._totalCachedFunctions = totalCachedFunctions
        self._configurations = configurations
    }
    
    // Computed property for cache efficiency metrics
    public var cacheEfficiency: Double {
        guard _totalCachedFunctions > 0 else { return 0.0 }
        let activeFunctions = _functionCounts.values.filter { $0 > 0 }.count
        return Double(activeFunctions) / Double(_totalCachedFunctions)
    }
    
    // Get statistics for a specific function
    public func getCachedCount(for functionName: String) -> Int {
        return _functionCounts[functionName] ?? 0
    }
}

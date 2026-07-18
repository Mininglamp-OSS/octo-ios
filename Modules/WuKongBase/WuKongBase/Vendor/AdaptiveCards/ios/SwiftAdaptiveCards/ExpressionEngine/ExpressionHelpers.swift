// MARK: - Objective-C Bridge
//
//  ExpressionHelpers.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - Objective-C Bridge Implementation

@objc public class ObjCExpressionEvaluator: NSObject {
    
    @objc public static let shared = ObjCExpressionEvaluator()
    
    private let engine: ExpressionEngineProtocol
    private var expressionEvalEnabled = false
    
    // Private initializer prevents external instantiation
    private override init() {
        self.engine = ExpressionEngine()
        super.init()
    }
    
    // MARK: - Configuration
    
    @objc public static func setExpressionEvalEnabled(_ isEnabled: Bool) {
        shared.expressionEvalEnabled = isEnabled
    }
    
    @objc public static func isExpressionEvalEnabled() -> Bool {
        return shared.expressionEvalEnabled
    }
        
    // Static convenience method for backward compatibility
    @objc public static func evaluateExpression(_ expressionString: String, withData data: NSDictionary? = nil, completion: @escaping (NSObject?, NSError?) -> Void) {
        shared.evaluateExpression(expressionString, withData: data, completion: completion)
    }
    
    /// Instance method for evaluating expressions
    @objc public func evaluateExpression(_ expressionString: String, withData data: NSDictionary? = nil, completion: @escaping (NSObject?, NSError?) -> Void) {
        
        Task {
            do {
                let expr = try engine.createExpression(expressionString, allowAssignment: false)
                let context: EvaluationContext?
                
                if let data = data {
                    context = await engine.createContext(with: data as? [String: Any])
                } else {
                    context = await engine.createDefaultContext(with: nil)
                }
                
                let result = await expr.evaluateResult(context: context)
                
                switch result {
                case .success(let value):
                    if let nsObj = value as? NSObject {
                        completion(nsObj, nil)
                    } else if let str = value as? String {
                        completion(str as NSString, nil)
                    } else if let num = value as? NSNumber {
                        completion(num, nil)
                    } else if let arr = value as? [Any] {
                        completion(arr as NSArray, nil)
                    } else if let dict = value as? [String: Any] {
                        completion(dict as NSDictionary, nil)
                    } else if let val = value {
                        completion(String(describing: val) as NSString, nil)
                    } else {
                        completion(nil, nil)
                    }
                case .failure(let error):
                    completion(nil, error as NSError)
                }
            } catch let error as NSError {
                completion(nil, error)
            } catch {
                let nsError = NSError(domain: "ObjCExpressionEvaluator", code: -1, userInfo: [NSLocalizedDescriptionKey: String(describing: error)])
                completion(nil, nsError)
            }
        }
    }
}

//
//  BinaryOperatorNode.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - BinaryOperatorNode

public class BinaryOperatorNode: EvaluationNode {
    private let operatorToken: BinaryOperatorToken
    
    public var operatorType: BinaryOperatorType {
        return BinaryOperatorType(from: operatorToken) ?? .equality
    }
    
    public init(operatorType: BinaryOperatorType) {
        self.operatorToken = operatorType.rawValue
    }
    
    public func evaluate(context: EvaluationContext, left: Any?, right: Any?) async throws -> EvaluationResult {
        // Handle list-specific operators first
        if let leftArray = left as? [Any] {
            switch operatorType {
            case .inclusion:
                if let rightArray = right as? [Any] {
                    return rightArray.contains { element in
                        if let leftElement = left {
                            return ExpressionUtilities.areEqual(leftElement, element)
                        }
                        return false
                    }
                }
            case .addition:
                if let rightArray = right as? [Any] {
                    return leftArray + rightArray
                } else if let rightElement = right {
                    return leftArray + [rightElement]
                }
            default:
                break
            }
        } else if let rightArray = right as? [Any] {
            switch operatorType {
            case .inclusion:
                return rightArray.contains { element in
                    if let leftElement = left {
                        return ExpressionUtilities.areEqual(leftElement, element)
                    }
                    return false
                }
            case .addition:
                if let leftElement = left {
                    return [leftElement] + rightArray
                }
            default:
                break
            }
        }
        
        // Handle general operators
        switch operatorType {
        case .division, .multiplication, .subtraction:
            guard let leftNum = ExpressionUtilities.toNumber(left) else {
                throw EvaluationError.invalidOperand("Left operand for operator '\(operatorType.rawValue)' must be a number, but got '\(String(describing: left))'")
            }
            guard let rightNum = ExpressionUtilities.toNumber(right) else {
                throw EvaluationError.invalidOperand("Right operand for operator '\(operatorType.rawValue)' must be a number, but got '\(String(describing: right))'")
            }
            
            switch operatorType {
            case .division:
                return leftNum / rightNum
            case .multiplication:
                return leftNum * rightNum
            case .subtraction:
                return leftNum - rightNum
            default:
                break
            }
            
        case .addition:
            if left is String || right is String {
                let leftStr = left as? String ?? ""
                let rightStr = right as? String ?? ""
                return leftStr + rightStr
            }
            guard let leftNum = ExpressionUtilities.toNumber(left) else {
                throw EvaluationError.invalidOperand("Left operand for '+' must be a number or string, but got '\(String(describing: left))'")
            }
            guard let rightNum = ExpressionUtilities.toNumber(right) else {
                throw EvaluationError.invalidOperand("Right operand for '+' must be a number or string, but got '\(String(describing: right))'")
            }
            return leftNum + rightNum
            
        case .equality:
            return ExpressionUtilities.areEqual(left, right)
        case .inequality:
            return !ExpressionUtilities.areEqual(left, right)
            
        case .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual:
            guard left != nil else {
                throw EvaluationError.invalidOperand("Left operand for operator '\(operatorType.rawValue)' is not comparable: '\(String(describing: left))'")
            }
            guard right != nil else {
                throw EvaluationError.invalidOperand("Left operand for operator '\(operatorType.rawValue)' is not comparable: '\(String(describing: right))'")
            }
            
            // Try to compare as numbers first (most common case)
            if let leftNum = ExpressionUtilities.toNumber(left), let rightNum = ExpressionUtilities.toNumber(right) {
                let comparisonResult: Int
                if leftNum < rightNum {
                    comparisonResult = -1
                } else if leftNum > rightNum {
                    comparisonResult = 1
                } else {
                    comparisonResult = 0
                }
                
                switch operatorType {
                case .lessThan:
                    return comparisonResult < 0
                case .lessThanOrEqual:
                    return comparisonResult <= 0
                case .greaterThan:
                    return comparisonResult > 0
                case .greaterThanOrEqual:
                    return comparisonResult >= 0
                default:
                    break
                }
            }
            
            // Fall back to generic comparable if not numbers
            guard let leftComp = left as? (any Comparable) else {
                throw EvaluationError.invalidOperand("Left operand for operator '\(operatorType.rawValue)' is not comparable: '\(String(describing: left))'")
            }
            
            guard let rightComp = right as? (any Comparable) else {
                throw EvaluationError.invalidOperand("Left operand for operator '\(operatorType.rawValue)' is not comparable: '\(String(describing: left))'")
            }

            let comparisonResult = try ExpressionUtilities.compareValues(leftComp, rightComp)
            
            switch operatorType {
            case .lessThan:
                return comparisonResult < 0
            case .lessThanOrEqual:
                return comparisonResult <= 0
            case .greaterThan:
                return comparisonResult > 0
            case .greaterThanOrEqual:
                return comparisonResult >= 0
            default:
                break
            }
            
        case .logicalAnd:
            let leftBool = ExpressionUtilities.toBool(left)
            let rightBool = ExpressionUtilities.toBool(right)
            return leftBool && rightBool
            
        case .logicalOr:
            let leftBool = ExpressionUtilities.toBool(left)
            let rightBool = ExpressionUtilities.toBool(right)
            return leftBool || rightBool
            
        case .inclusion:
            // This case is handled above for arrays, but we need it here too for completeness
            break
        }
        
        throw EvaluationError.incompatibleOperator("Operator '\(operatorType.rawValue)' is not compatible with operand types \(type(of: left)) and \(type(of: right))")
    }
    
    public func evaluate(context: EvaluationContext) async throws -> EvaluationResult {
        throw EvaluationError.unsupportedOperation("BinaryOperatorNode cannot be evaluated directly.")
    }
}

import Foundation
import UIKit
import AsyncDisplayKit

 public func createGradientBackgroundNode(colors: [UIColor]? = nil, useSharedAnimationPhase: Bool = false) -> GradientBackgroundNode {
    return GradientBackgroundNode(colors: colors, useSharedAnimationPhase: useSharedAnimationPhase)
}

// Copyright 2024 MININGLAMP. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
// OctoMessageGestureContainerNode
// -------------------------------
// 挂载 OctoContextGesture 的 ASDisplayNode 容器。Octo 独立实现，替代旧
// TelegramUtils/Display/Source/ContextControllerSourceNode.swift（GPL v2）。
//
// 设计要点：
//   * 通过 `didLoad()` 在底层 UIView 上注册一个 OctoContextGesture，把
//     cell 设的 shouldBegin/activated 透传给 gesture。
//   * 提供 `targetNodeForActivationProgress` —— 默认走 0.98 微缩放视觉反馈；
//     `animateScale=false` 时关闭。
//   * `targetNodeForActivationProgressContentRectForOCWithRect:` 保留 OC 端
//     互调用签名（WKMessageCell.m:1102 在用），仅记录矩形，未做额外动画。
//   * `isGestureEnabled` setter 同步 gesture.isEnabled，cell 进入多选模式时
//     用来禁用长按。

import Foundation
import UIKit
import AsyncDisplayKit

@objc open class OctoMessageGestureContainerNode: ASDisplayNode {

    public private(set) var contextGesture: OctoContextGesture?

    @objc public var isGestureEnabled: Bool = true {
        didSet { contextGesture?.isEnabled = isGestureEnabled }
    }

    @objc public var beginDelay: TimeInterval = 0.12 {
        didSet { contextGesture?.beginDelay = beginDelay }
    }

    @objc public var animateScale: Bool = true

    @objc public var activated: ((OctoContextGesture, CGPoint) -> Void)?
    @objc public var shouldBegin: ((CGPoint) -> Bool)?
    public var customActivationProgress: ((CGFloat, OctoContextGestureTransition) -> Void)?

    @objc public var targetNodeForActivationProgress: ASDisplayNode?
    public var targetNodeForActivationProgressContentRect: CGRect?

    // MARK: - Setup

    public override init() {
        super.init()
        self.isUserInteractionEnabled = true
    }

    open override func didLoad() {
        super.didLoad()
        let gesture = OctoContextGesture(target: nil, action: nil)
        gesture.beginDelay = beginDelay
        gesture.isEnabled = isGestureEnabled

        gesture.shouldBegin = { [weak self] point in
            guard let self = self else { return false }
            return self.shouldBegin?(point) ?? true
        }
        gesture.activated = { [weak self] g, point in
            self?.activated?(g, point)
        }
        gesture.activationProgress = { [weak self] progress, transition in
            guard let self = self else { return }
            if let custom = self.customActivationProgress {
                custom(progress, transition)
            } else if self.animateScale {
                self.applyDefaultScale(progress: progress, transition: transition)
            }
        }
        self.view.addGestureRecognizer(gesture)
        self.contextGesture = gesture
    }

    private func applyDefaultScale(progress: CGFloat, transition: OctoContextGestureTransition) {
        guard let target = targetNodeForActivationProgress else { return }
        // 0.98 → 1.0 区间的微缩放，不打断滚动观感
        let scale: CGFloat
        switch transition {
        case .ended:
            scale = 1.0
        default:
            scale = 1.0 - 0.02 * max(0, min(progress, 1))
        }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            target.transform = CATransform3DMakeScale(scale, scale, 1.0)
        })
    }

    // MARK: - Public ops

    @objc public func cancelGesture() {
        contextGesture?.cancel()
    }

    @objc public func targetNodeForActivationProgressContentRectForOCWithRect(_ rect: CGRect) {
        targetNodeForActivationProgressContentRect = rect
    }
}

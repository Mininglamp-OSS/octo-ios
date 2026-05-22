// Copyright 2024 MININGLAMP. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
// OctoContextGesture
// ------------------
// 聊天气泡长按出菜单的自定义识别器。Octo 独立实现，替代旧
// TelegramUtils/Display/Source/ContextGesture.swift（GPL v2）。
//
// 设计目标（cf. CLAUDE.md 工程规范，README "长期工作" 段落）：
//   1) 0.12s 起手延迟 — 给 UITableView 的 panGesture 抢占窗口，避免滚动卡顿。
//   2) 左缘 8pt 起手直接失败 — 让 interactivePopGestureRecognizer 拿到右滑返回。
//   3) shouldRecognizeSimultaneouslyWith UIPanGestureRecognizer 返回 false —
//      永不和 scroll 并行识别。
//   4) 进度阶段 0.2s — 在此期间任何取消（手指滑走 / touchesCancelled）都要把
//      activationProgress 回调成 .ended(previousProgress) 让上层缩放回弹。
//   5) 3D Touch force ≥ max(2.5, min(3.0, maxForce)) 时跳过 0.12s 立刻激活。
//
// 回退开关：设置 `OctoContextGesture.disableForSafeMode = true` 后所有实例
// 在 touchesBegan 立即 .failed，让外层的 UILongPressGestureRecognizer fallback
// 接管。开发期排障专用。

import Foundation
import UIKit

@objc public enum OctoContextGestureTransitionKind: Int {
    case begin = 0
    case update = 1
    case ended = 2
}

public enum OctoContextGestureTransition {
    case begin
    case update
    case ended(CGFloat)
}

@objc public final class OctoContextGesture: UIGestureRecognizer, UIGestureRecognizerDelegate {

    // ---- 调试开关 ----
    @objc public static var disableForSafeMode: Bool = false

    // ---- 可配置参数 ----
    @objc public var beginDelay: TimeInterval = 0.12
    @objc public var activationDuration: TimeInterval = 0.2
    @objc public var leftEdgeIgnoreWidth: CGFloat = 8.0

    // ---- 状态 ----
    private var armTimer: Foundation.Timer?
    private var displayLink: CADisplayLink?
    private var progressStartTime: CFTimeInterval = 0
    private var currentProgress: CGFloat = 0
    private var didActivate: Bool = false
    private var beganLocation: CGPoint = .zero

    // ---- 回调（保持与原消费方一致的语义） ----
    public var shouldBegin: ((CGPoint) -> Bool)?
    public var activated: ((OctoContextGesture, CGPoint) -> Void)?
    public var activationProgress: ((CGFloat, OctoContextGestureTransition) -> Void)?
    public var externalUpdated: ((UIView?, CGPoint) -> Void)?
    public var externalEnded: (((UIView?, CGPoint)?) -> Void)?
    public var activatedAfterCompletion: (() -> Void)?

    // OC 桥（block 不便携枚举关联值，单独走一个）
    @objc public var activatedForOC: ((OctoContextGesture, CGPoint) -> Void)?
    @objc public var shouldBeginForOC: ((CGPoint) -> Bool)?

    // MARK: - Lifecycle

    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        self.delegate = self
        self.cancelsTouchesInView = false
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }

    public override func reset() {
        super.reset()
        invalidateTimers()
        currentProgress = 0
        didActivate = false
        externalUpdated = nil
        externalEnded = nil
    }

    private func invalidateTimers() {
        armTimer?.invalidate()
        armTimer = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - UIGestureRecognizerDelegate

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 关键：不和 scrollview 的 pan 并行 — 滑动优先。其它（tap 等）可以并行。
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return true
    }

    // MARK: - Touches

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        if OctoContextGesture.disableForSafeMode {
            state = .failed
            return
        }
        guard let touch = touches.first else {
            state = .failed
            return
        }

        let location = touch.location(in: self.view)
        beganLocation = location

        // 左缘 8pt 让位给 interactivePop
        let windowLocation = touch.location(in: nil)
        if windowLocation.x < leftEdgeIgnoreWidth {
            state = .failed
            return
        }

        // 让 cell 有否决权
        if let shouldBegin = self.shouldBegin, !shouldBegin(location) {
            state = .failed
            return
        }
        if let shouldBeginOC = self.shouldBeginForOC, !shouldBeginOC(location) {
            state = .failed
            return
        }

        scheduleArm(at: location)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }

        // 3D Touch 旁路
        if #available(iOS 9.0, *) {
            let force = touch.force
            if force > 0 {
                let threshold = max(2.5, min(3.0, touch.maximumPossibleForce))
                if force >= threshold, state == .possible {
                    activateNow(at: touch.location(in: self.view))
                }
            }
        }

        externalUpdated?(self.view, touch.location(in: self.view))
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        let touch = touches.first
        let loc = touch?.location(in: self.view) ?? beganLocation

        finishGesture(loc: loc, sendExternalEnded: true)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        let loc = touches.first?.location(in: self.view) ?? beganLocation
        finishGesture(loc: loc, sendExternalEnded: false)
    }

    // MARK: - Internal state machine

    private func scheduleArm(at location: CGPoint) {
        let timer = Foundation.Timer(timeInterval: beginDelay, repeats: false) { [weak self] _ in
            self?.armDidFire(at: location)
        }
        RunLoop.main.add(timer, forMode: .common)
        armTimer = timer
    }

    private func armDidFire(at location: CGPoint) {
        guard state == .possible else { return }
        activationProgress?(0, .begin)
        startProgressAnimation(target: location)
    }

    private func startProgressAnimation(target: CGPoint) {
        displayLink?.invalidate()
        progressStartTime = CACurrentMediaTime()
        let link = CADisplayLink(target: DisplayLinkProxy { [weak self] in
            self?.progressTick(target: target)
        }, selector: #selector(DisplayLinkProxy.fire))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func progressTick(target: CGPoint) {
        guard state == .possible else {
            displayLink?.invalidate()
            displayLink = nil
            return
        }
        let elapsed = CACurrentMediaTime() - progressStartTime
        let p = CGFloat(min(max(elapsed / activationDuration, 0), 1))
        currentProgress = p
        activationProgress?(p, .update)
        if p >= 1 {
            displayLink?.invalidate()
            displayLink = nil
            activateNow(at: target)
        }
    }

    private func activateNow(at location: CGPoint) {
        guard state == .possible else { return }
        invalidateTimers()
        didActivate = true
        currentProgress = 1
        // 走 .began 让 UIKit 把这次手势认下来；UI 后续展示菜单。
        state = .began
        activated?(self, location)
        activatedForOC?(self, location)
    }

    private func finishGesture(loc: CGPoint, sendExternalEnded: Bool) {
        let previousProgress = currentProgress
        let wasActivated = didActivate

        invalidateTimers()
        currentProgress = 0

        if previousProgress > 0 {
            activationProgress?(0, .ended(previousProgress))
        }
        if wasActivated {
            activatedAfterCompletion?()
        }
        if sendExternalEnded {
            externalEnded?((self.view, loc))
        } else {
            externalEnded?(nil)
        }

        if state == .began {
            state = .ended
        } else {
            state = .failed
        }
    }

    // MARK: - Public ops

    @objc public func cancel() {
        let previousProgress = currentProgress
        invalidateTimers()
        currentProgress = 0
        if previousProgress > 0 {
            activationProgress?(0, .ended(previousProgress))
        }
        if state != .failed && state != .ended {
            state = .failed
        }
    }

    @objc public func endPressedAppearance() {
        let previousProgress = currentProgress
        if previousProgress > 0 {
            currentProgress = 0
            activationProgress?(0, .ended(previousProgress))
        }
        displayLink?.invalidate()
        displayLink = nil
    }
}

// CADisplayLink 不能 weak target；用一个 thin proxy 避免循环引用。
private final class DisplayLinkProxy {
    let onFire: () -> Void
    init(_ onFire: @escaping () -> Void) { self.onFire = onFire }
    @objc func fire() { onFire() }
}

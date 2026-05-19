// Copyright 2024 MININGLAMP. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
// OctoTapLongTapOrDoubleTapRecognizer
// -----------------------------------
// 多态点击识别器：在同一次手势序列里区分 tap / double-tap / long-tap / hold。
// Octo 独立实现，替代旧 TelegramUtils/Display/Source/
// TapLongTapOrDoubleTapGestureRecognizer.swift（GPL v2）。
//
// 行为目标：
//   * touchesBegan 时回调宿主 `tapActionAtPoint(point)`，按返回的 action 决定后续：
//       - .fail：立即 .failed
//       - .waitForSingleTap：启动 longPress 计时（0.3s），抬手前判定为 single tap
//       - .waitForDoubleTap：抬手后启动 doubleTap 窗口（0.3s），等下一次 down
//       - .keepWithSingleTap：禁用 longPress，仅认 single tap
//   * 任意阶段，手指移动 > tapMaxDistance(4pt) 视为滚动意图 -> .failed
//     （配合 `shouldRecognizeSimultaneouslyWith UIPanGestureRecognizer=false`
//      保证滚动顺畅，且不会误识别长按）。
//   * 长按 0.3s 触发 .longTap + longTap callback；继续按住到 0.6s 累计触发 .hold。
//   * 识别结果写入 lastRecognizedGestureAndLocation，宿主在 state==.ended 时读取。

import Foundation
import UIKit

@objc public enum OctoTapKind: Int {
    case tap = 0
    case doubleTap = 1
    case longTap = 2
    case hold = 3
}

@objc public enum OctoTapAction: Int {
    case none = 0
    case waitForDoubleTap = 1
    case waitForSingleTap = 2
    case fail = 3
    case keepWithSingleTap = 4
}

@objc public final class OctoTapLongTapOrDoubleTapRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {

    // ---- Tunables ----
    @objc public var longPressDuration: TimeInterval = 0.3
    @objc public var holdDuration: TimeInterval = 0.6
    @objc public var doubleTapWindow: TimeInterval = 0.3
    @objc public var tapMaxDistance: CGFloat = 4.0

    // ---- Public state ----
    @objc public private(set) var lastRecognizedKind: OctoTapKind = .tap
    @objc public private(set) var lastRecognizedLocation: CGPoint = .zero
    @objc public private(set) var hasRecognized: Bool = false

    // Swift-friendly accessor
    public var lastRecognizedGestureAndLocation: (OctoTapKind, CGPoint)? {
        return hasRecognized ? (lastRecognizedKind, lastRecognizedLocation) : nil
    }

    // ---- Callbacks ----
    public var tapActionAtPoint: ((CGPoint) -> OctoTapAction)?
    public var longTap: ((CGPoint, OctoTapLongTapOrDoubleTapRecognizer) -> Void)?
    public var highlight: ((CGPoint?) -> Void)?
    public var externalUpdated: ((UIView?, CGPoint) -> Void)?
    public var externalEnded: (((UIView?, CGPoint)?) -> Void)?

    @objc public var tapActionAtPointForOC: ((CGPoint) -> OctoTapAction)?
    @objc public var longTapForOC: ((CGPoint, OctoTapLongTapOrDoubleTapRecognizer) -> Void)?

    // ---- Internal phase ----
    private enum Phase {
        case idle
        case awaitingFirstUp(action: OctoTapAction)
        case awaitingSecondDown    // double tap window
        case awaitingSecondUp      // got second down, waiting for up
        case finishedAsLongPress
    }

    private var phase: Phase = .idle
    private var startLocation: CGPoint = .zero
    private var longPressTimer: Foundation.Timer?
    private var holdTimer: Foundation.Timer?
    private var doubleTapTimer: Foundation.Timer?
    private var tapCount: Int = 0

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
        phase = .idle
        tapCount = 0
        hasRecognized = false
    }

    private func invalidateTimers() {
        longPressTimer?.invalidate(); longPressTimer = nil
        holdTimer?.invalidate(); holdTimer = nil
        doubleTapTimer?.invalidate(); doubleTapTimer = nil
    }

    // MARK: - Delegate

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return true
    }

    // MARK: - Touches

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else {
            state = .failed
            return
        }
        let location = touch.location(in: self.view)
        startLocation = location

        // 处于 doubleTap 等待中：这是第二次按下
        if case .awaitingSecondDown = phase {
            doubleTapTimer?.invalidate(); doubleTapTimer = nil
            tapCount = 2
            phase = .awaitingSecondUp
            return
        }

        // 全新一次起手 — 询问宿主
        let actionCB = tapActionAtPoint ?? tapActionAtPointForOC
        let action = actionCB?(location) ?? .waitForSingleTap

        switch action {
        case .fail, .none:
            state = .failed
            return
        case .waitForSingleTap, .waitForDoubleTap:
            phase = .awaitingFirstUp(action: action)
            tapCount = 1
            startLongPressTimer()
            startHoldTimer()
        case .keepWithSingleTap:
            phase = .awaitingFirstUp(action: action)
            tapCount = 1
            // 不启动 longPress
        }

        highlight?(location)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let location = touch.location(in: self.view)
        let dx = location.x - startLocation.x
        let dy = location.y - startLocation.y
        if (dx * dx + dy * dy).squareRoot() > tapMaxDistance {
            // 滑动 — 让位给 scroll
            highlight?(nil)
            cancelInternal()
            return
        }
        externalUpdated?(self.view, location)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first else {
            state = .failed
            return
        }
        let location = touch.location(in: self.view)

        switch phase {
        case .finishedAsLongPress:
            // longTap/hold 已在 timer 回调中识别；此处只收尾
            externalEnded?((self.view, location))
            highlight?(nil)
            state = .ended
        case .awaitingFirstUp(let action):
            longPressTimer?.invalidate(); longPressTimer = nil
            holdTimer?.invalidate(); holdTimer = nil
            if action == .waitForDoubleTap {
                // 等下一次 down
                phase = .awaitingSecondDown
                startDoubleTapTimer(location: location)
                // 不结束手势，留 .possible
            } else {
                recognize(kind: .tap, location: location)
                externalEnded?((self.view, location))
                highlight?(nil)
                state = .ended
            }
        case .awaitingSecondUp:
            recognize(kind: .doubleTap, location: location)
            externalEnded?((self.view, location))
            highlight?(nil)
            state = .ended
        case .awaitingSecondDown, .idle:
            // 不应到这；安全收尾
            state = .failed
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        externalEnded?(nil)
        highlight?(nil)
        cancelInternal()
    }

    // MARK: - Timers

    private func startLongPressTimer() {
        longPressTimer?.invalidate()
        let t = Foundation.Timer(timeInterval: longPressDuration, repeats: false) { [weak self] _ in
            self?.longPressFired()
        }
        RunLoop.main.add(t, forMode: .common)
        longPressTimer = t
    }

    private func startHoldTimer() {
        holdTimer?.invalidate()
        let t = Foundation.Timer(timeInterval: holdDuration, repeats: false) { [weak self] _ in
            self?.holdFired()
        }
        RunLoop.main.add(t, forMode: .common)
        holdTimer = t
    }

    private func startDoubleTapTimer(location: CGPoint) {
        doubleTapTimer?.invalidate()
        let t = Foundation.Timer(timeInterval: doubleTapWindow, repeats: false) { [weak self] _ in
            self?.doubleTapWindowExpired(location: location)
        }
        RunLoop.main.add(t, forMode: .common)
        doubleTapTimer = t
    }

    private func longPressFired() {
        guard case .awaitingFirstUp = phase else { return }
        phase = .finishedAsLongPress
        recognize(kind: .longTap, location: startLocation)
        let cb = longTap ?? longTapForOC
        cb?(startLocation, self)
        // 状态仍保持 .possible，待 touchesEnded 收尾时设为 .ended
        // 这样宿主在 .ended 时仍能读到 lastRecognizedKind == .longTap
    }

    private func holdFired() {
        guard case .finishedAsLongPress = phase else {
            // 没走到 longPress（如直接抬手）就不该走 hold
            return
        }
        // 升级为 hold：覆盖识别结果
        recognize(kind: .hold, location: startLocation)
    }

    private func doubleTapWindowExpired(location: CGPoint) {
        guard case .awaitingSecondDown = phase else { return }
        // 在窗口内没等到第二次 down — 当 single tap
        recognize(kind: .tap, location: location)
        externalEnded?((self.view, location))
        highlight?(nil)
        state = .ended
    }

    // MARK: - Helpers

    private func recognize(kind: OctoTapKind, location: CGPoint) {
        lastRecognizedKind = kind
        lastRecognizedLocation = location
        hasRecognized = true
    }

    @objc public func cancel() {
        cancelInternal()
    }

    private func cancelInternal() {
        invalidateTimers()
        phase = .idle
        if state != .failed && state != .ended {
            state = .failed
        }
    }
}

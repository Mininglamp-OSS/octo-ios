// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  TapLongTapOrDoubleTapGestureRecognizerWrap.swift
//  WuKongBase
//
//  Native UIKit replacement for the Telegram-based gesture wrapper (P5).
//  Public ObjC interface unchanged so WKMessageCell / WKTextMessageCell /
//  WKVoiceMessageCell can use it without modification.
//

import Foundation
import UIKit

@objc public class TapLongTapOrDoubleTapGestureRecognizerWrap: NSObject, UIGestureRecognizerDelegate {

    /// 暴露给外部用于 setEnabled: 启停手势（WKMessageCell 用过）。
    /// 这里返回长按 recognizer；如需停 tap，可改成内部聚合控制。
    @objc public var gesture: UIGestureRecognizer?

    @objc public var tapAction: WKTapLongTapOrDoubleTapGesture
    @objc public var tapPoint: CGPoint

    private let action: (_ gesture: TapLongTapOrDoubleTapGestureRecognizerWrap) -> Void?

    /// 命中测试回调：业务方根据触点决定是否进入手势（fail/wait/keepWithSingleTap）。
    /// 这里用于在 contentView 上做选择性过滤；返回 fail 时不接入 tap/longTap。
    @objc public var tapActionAtPoint: ((CGPoint) -> WKTapLongTapOrDoubleTapGestureRecognizerEvent)?

    /// 长按回调（不会和单击冲突）。
    @objc public var longTap: ((CGPoint, TapLongTapOrDoubleTapGestureRecognizerWrap) -> Void)?

    private var tapRecognizer: UITapGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var longPressRecognizer: UILongPressGestureRecognizer?
    private weak var attachedView: UIView?

    @objc public init(action: @escaping (_ gesture: TapLongTapOrDoubleTapGestureRecognizerWrap) -> Void) {
        self.action = action
        self.tapPoint = .zero
        self.tapAction = WKTapLongTapOrDoubleTapGestureTap
        super.init()
    }

    @objc public func setup() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        self.tapRecognizer = tap

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        self.doubleTapRecognizer = doubleTap

        tap.require(toFail: doubleTap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        longPress.delegate = self
        self.longPressRecognizer = longPress

        self.gesture = longPress
    }

    @objc public func attachToView(_ view: UIView) {
        attachedView = view
        if let tap = tapRecognizer { view.addGestureRecognizer(tap) }
        if let doubleTap = doubleTapRecognizer { view.addGestureRecognizer(doubleTap) }
        if let longPress = longPressRecognizer { view.addGestureRecognizer(longPress) }
    }

    // MARK: - UIGestureRecognizerDelegate

    public func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                                  shouldReceive touch: UITouch) -> Bool {
        guard let callback = tapActionAtPoint, let view = attachedView else {
            return true
        }
        let point = touch.location(in: view)
        let event = callback(point)
        switch event.action {
        case WKTapLongTapOrDoubleTapGestureRecognizerActionFail:
            return false
        default:
            return true
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    // MARK: - Handlers

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        guard gr.state == .ended, let view = attachedView else { return }
        self.tapPoint = gr.location(in: view)
        self.tapAction = WKTapLongTapOrDoubleTapGestureTap
        _ = self.action(self)
    }

    @objc private func handleDoubleTap(_ gr: UITapGestureRecognizer) {
        guard gr.state == .ended, let view = attachedView else { return }
        self.tapPoint = gr.location(in: view)
        self.tapAction = WKTapLongTapOrDoubleTapGestureDoubleTap
        _ = self.action(self)
    }

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began, let view = attachedView else { return }
        let point = gr.location(in: view)
        self.tapPoint = point
        self.tapAction = WKTapLongTapOrDoubleTapGestureLongTap

        if let lt = self.longTap {
            lt(point, self)
        } else {
            _ = self.action(self)
        }
    }
}

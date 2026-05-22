// Copyright 2024 MININGLAMP. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
//  TapLongTapOrDoubleTapGestureRecognizerWrap.swift
//  WuKongBase
//
//  WKMessageCell 等 OC cell 使用的 Wrap。内部识别器从旧 GPL 版
//  TapLongTapOrDoubleTapGestureRecognizer 切到 Octo 自实现的
//  OctoTapLongTapOrDoubleTapRecognizer（见 MessageGesture/ 目录）。
//

import Foundation
import UIKit

@objc public class TapLongTapOrDoubleTapGestureRecognizerWrap: NSObject {
    @objc public  var gesture: OctoTapLongTapOrDoubleTapRecognizer?
    @objc public var tapAction: WKTapLongTapOrDoubleTapGesture
    @objc public var tapPoint: CGPoint
    let action: (_ gesture: TapLongTapOrDoubleTapGestureRecognizerWrap) -> Void?
    @objc public var tapActionAtPoint: ((CGPoint) -> WKTapLongTapOrDoubleTapGestureRecognizerEvent)?
    @objc public var longTap: ((CGPoint, TapLongTapOrDoubleTapGestureRecognizerWrap) -> Void)?

    @objc public init(action: @escaping (_ gesture: TapLongTapOrDoubleTapGestureRecognizerWrap) -> Void) {
        self.action = action
        self.tapPoint = CGPoint()
        self.tapAction = WKTapLongTapOrDoubleTapGestureTap
    }

    @objc public func setup() {
        let g = OctoTapLongTapOrDoubleTapRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))

        g.tapActionAtPoint = { [weak self] point in
            guard let strongSelf = self else { return .fail }
            guard let event = strongSelf.tapActionAtPoint?(point) else { return .fail }
            switch event.action {
            case WKTapLongTapOrDoubleTapGestureRecognizerActionWaitForSingleTap:
                return .waitForSingleTap
            case WKTapLongTapOrDoubleTapGestureRecognizerActionWaitForDoubleTap:
                return .waitForDoubleTap
            case WKTapLongTapOrDoubleTapGestureRecognizerActionKeepWithSingleTap:
                return .keepWithSingleTap
            case WKTapLongTapOrDoubleTapGestureRecognizerActionFail:
                return .fail
            default:
                return .fail
            }
        }

        g.longTap = { [weak self] point, _ in
            guard let strongSelf = self else { return }
            strongSelf.longTap?(point, strongSelf)
        }

        self.gesture = g
    }

    @objc public func attachToView(_ view: UIView) {
        guard let g = self.gesture else { return }
        view.addGestureRecognizer(g)
    }

    @objc
    func tapLongTapOrDoubleTapGesture(_ recognizer: OctoTapLongTapOrDoubleTapRecognizer) {
        switch recognizer.state {
        case .ended:
            guard let (kind, location) = recognizer.lastRecognizedGestureAndLocation else { return }
            self.tapPoint = location
            switch kind {
            case .tap:       self.tapAction = WKTapLongTapOrDoubleTapGestureTap
            case .doubleTap: self.tapAction = WKTapLongTapOrDoubleTapGestureDoubleTap
            case .longTap:   self.tapAction = WKTapLongTapOrDoubleTapGestureLongTap
            case .hold:      self.tapAction = WKTapLongTapOrDoubleTapGestureHold
            }
            _ = self.action(self)
        default:
            break
        }
    }
}

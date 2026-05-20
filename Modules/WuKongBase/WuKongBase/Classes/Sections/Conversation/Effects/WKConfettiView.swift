// Copyright 2026 MININGLAMP. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
// WKConfettiView
// --------------
// 🎉 / 🎊 表情触发的彩纸礼花效果。本类是 SPConfetti (MIT, ivanvorobei)
// 的 thin wrapper，对外保持 WKPartyEffect.m 原本就在用的 OC 初始化
// 签名 (init(frame:customImage:))，让上层调用零修改。
//
// 行为：
//   1) 加入视图层级 (didMoveToSuperview != nil) 时启动 SPConfetti 全屏粒子
//   2) 从视图层级移除时停止粒子
//   3) WKMessageEffectView 在 ~10s 后会把整个容器移走（已有逻辑），随之触发停止
//
// customImage：保留参数兼容旧签名，SPConfetti 没有该 API；当前忽略
//             （传 nil 即可，业务上 WKPartyEffect.m 也是传 nil）。
//
// SPConfetti 来源 / license 详见 NOTICE。

import Foundation
import UIKit
import SPConfetti

@objc public final class WKConfettiView: UIView {

    private let customImage: UIImage?
    private var didStart = false

    // MARK: - Init (保持 OC 调用面不变)

    @objc public init(frame: CGRect, customImage: UIImage?) {
        self.customImage = customImage
        super.init(frame: frame)
        commonInit()
    }

    @objc public override init(frame: CGRect) {
        self.customImage = nil
        super.init(frame: frame)
        commonInit()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    // MARK: - Lifecycle

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil, !didStart {
            didStart = true
            // 默认 6s 撒落 + 4s 余韵 = 与 WKMessageEffectView 的 10s 移除节奏对齐。
            // 形状选 [.triangle, .arc, .polygon, .star] 模拟真实彩纸 + 亮片混合。
            SPConfetti.startAnimating(
                .fullWidthToDown,
                particles: [.triangle, .arc, .polygon, .star],
                duration: 6.0
            )
        } else if superview == nil, didStart {
            SPConfetti.stopAnimating()
        }
    }
}

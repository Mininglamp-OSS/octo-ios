// Copyright 2026 MININGLAMP. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
// WKConfettiView
// --------------
// 🎉 / 🎊 表情触发的彩纸礼花效果。本类是 thin wrapper —— 同时支持 2 个
// 第三方 MIT 库，运行时由 `Backend.current` 常量选择哪个，方便目视对比
// 哪种风格更符合产品观感。
//
// 切换方式：改 `Backend.current` 这一个常量后 rebuild。
//
// 两个候选（全部 MIT、CocoaPods 可用、新 Swift 能编）：
//   .swiftConfettiView   2.0.0 (2026-02) — 含 burst / depth / 3D 感 / haptic / sound
//                                          预设 .perfect = intense burst
//   .spConfetti          1.4.0 (2022-01) — 简洁，4 种发射方向 + 6 种粒子
//
// 选定一种后，可以从 podspec 移掉另外一个 pod，并把 Backend 简化掉。
//
// 公共 OC 调用面保持 init(frame:customImage:) / init(frame:) 不变 —
// 上层 WKPartyEffect.m 永远零改动。
//
// 各库 license / 致谢见 NOTICE。

import Foundation
import UIKit
import SPConfetti
import SwiftConfettiView

@objc public final class WKConfettiView: UIView {

    /// 当前选用的礼花库。改这一行 + rebuild 即可换风格。
    private enum Backend {
        case swiftConfettiView
        case spConfetti

        static let current: Backend = .swiftConfettiView   // ← 切这里
    }

    private let customImage: UIImage?
    private var didStart = false

    // SwiftConfettiView 的实例视图（生命周期挂在 WKConfettiView 上）
    private var swiftConfettiInstance: SwiftConfettiView?

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

    // MARK: - Lifecycle dispatch

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard superview != nil, !didStart else {
            if superview == nil, didStart { stop() }
            return
        }
        didStart = true
        start()
    }

    private func start() {
        switch Backend.current {
        case .swiftConfettiView: startSwiftConfetti()
        case .spConfetti:        startSPConfetti()
        }
    }

    private func stop() {
        switch Backend.current {
        case .swiftConfettiView: swiftConfettiInstance?.stopConfetti()
        case .spConfetti:        SPConfetti.stopAnimating()
        }
    }

    // MARK: - SwiftConfettiView 2.0.0 (preset .perfect: burst + depth + haptic)

    private func startSwiftConfetti() {
        let v = SwiftConfettiView(frame: bounds)
        v.applyPreset(.perfect)
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(v)
        v.startConfetti()
        swiftConfettiInstance = v
    }

    // MARK: - SPConfetti 1.4.0

    private func startSPConfetti() {
        SPConfetti.startAnimating(
            .fullWidthToDown,
            particles: [.triangle, .arc, .polygon, .star],
            duration: 6.0
        )
    }
}


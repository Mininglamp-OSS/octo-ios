// Copyright 2026 MININGLAMP. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
// WKConfettiView
// --------------
// 🎉 / 🎊 表情触发的彩纸礼花动画。基于 Apple 标准 CAEmitterLayer 粒子
// 系统的 clean-room 实现（不再 derive 自任何 GPL 上游）。
//
// 消费方（仅这两个）：
//   - WKPartyEffect.m: `[[WKConfettiView alloc] initWithFrame:b customImage:nil]`
//   - addSubview，10 秒后由 WKMessageEffectView 自动移除整体容器
//
// 设计要点：
//   1) 顶部一条线发射器 emitterShape=.line，birthRate 批量喷洒
//   2) 短脉冲（约 0.4s）后把 birthRate 置零，已生成的粒子继续下落+旋转
//   3) 每片纸屑：随机颜色（六色调色盘），随机自旋，重力加速
//   4) lifetime 6s + alphaSpeed 衰减让尾段自然褪色，避免硬切换
//   5) customImage 非空则覆盖默认彩色矩形纹理（外部传入特殊贴图时备用）

import Foundation
import UIKit
import QuartzCore

@objc public final class WKConfettiView: UIView {

    private let emitter = CAEmitterLayer()
    private let customImage: UIImage?

    // MARK: - Lifecycle

    @objc public init(frame: CGRect, customImage: UIImage?) {
        self.customImage = customImage
        super.init(frame: frame)
        setupCommon()
    }

    @objc public override init(frame: CGRect) {
        self.customImage = nil
        super.init(frame: frame)
        setupCommon()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupCommon() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.addSublayer(emitter)

        configureEmitter()
        layoutEmitter()

        // 一次脉冲后停止喷洒，让已生成的粒子继续走完 lifetime。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.emitter.birthRate = 0
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layoutEmitter()
    }

    private func layoutEmitter() {
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -8)
        emitter.emitterSize = CGSize(width: bounds.width, height: 2)
    }

    // MARK: - Emitter cells

    private func configureEmitter() {
        emitter.emitterShape = .line
        emitter.renderMode = .additive  // 重叠时颜色相加，更"喜庆"
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = makeCells()
        emitter.birthRate = 1.0
    }

    /// 每种颜色一个 cell。颜色调色盘选了 6 个比较喜庆的组合。
    private func makeCells() -> [CAEmitterCell] {
        let palette: [UIColor] = [
            UIColor(red: 0.97, green: 0.27, blue: 0.36, alpha: 1.0), // 红
            UIColor(red: 1.00, green: 0.65, blue: 0.13, alpha: 1.0), // 橙
            UIColor(red: 1.00, green: 0.85, blue: 0.18, alpha: 1.0), // 黄
            UIColor(red: 0.30, green: 0.78, blue: 0.45, alpha: 1.0), // 绿
            UIColor(red: 0.27, green: 0.60, blue: 0.97, alpha: 1.0), // 蓝
            UIColor(red: 0.74, green: 0.40, blue: 0.93, alpha: 1.0), // 紫
        ]

        return palette.map { color in
            let cell = CAEmitterCell()
            cell.contents = (customImage?.cgImage) ?? Self.defaultStripImage(color: color).cgImage

            // 喷洒强度：每秒每个 cell 出 18 片，6 个 cell × 0.4s 脉冲 ≈ 43 片
            cell.birthRate = 18.0
            cell.lifetime = 6.0
            cell.lifetimeRange = 1.5

            // 速度：往下散开为主（emissionLongitude=π/2 是 +y / 屏幕下方）
            cell.velocity = 220
            cell.velocityRange = 80
            cell.emissionLongitude = .pi / 2
            cell.emissionRange = .pi / 5  // ±36° 散度

            // 重力 + 自旋
            cell.yAcceleration = 110
            cell.xAcceleration = 0
            cell.spin = 0
            cell.spinRange = 8.0  // 每秒 ±8 rad/s

            // 大小 + 透明度衰减
            cell.scale = 0.6
            cell.scaleRange = 0.2
            cell.scaleSpeed = -0.04
            cell.alphaSpeed = -0.18
            return cell
        }
    }

    // MARK: - Default strip texture

    /// 8×16 的小矩形纸屑纹理 —— 模拟真实纸屑长条形。带圆角让边缘柔和。
    private static func defaultStripImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 8, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(color.cgColor)
            let path = UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: 1.5
            )
            path.fill()
        }
    }
}

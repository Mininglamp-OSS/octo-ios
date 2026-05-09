//
//  WKRocketSmokeCloud.swift
//  WuKongBase
//
//  基于 SpriteKit 的火箭发射烟雾云
//
//  比 CAEmitterLayer 优势：
//    - SKFieldNode.turbulenceField → 真实的涡流扰动，每个烟团飘动轨迹都不同
//    - SKFieldNode.noiseField → 缓慢有机的气流推动
//    - SKEmitterNode 自带 particleRotationSpeed / particleScaleSpeed 曲线
//    - 粒子受物理场影响 → 烟团之间看似互相"推挤"，符合真实烟雾翻滚感
//
//  挂在 effectView 上（**不跟随火箭**），位置固定在发射点两侧。
//  火箭升空后 stop 即可，已生成的粒子会受场力继续翻滚并自然淡出。
//
//  对外 @objc API 供 Objective-C WKRocketLaunchEffect 调用。

import Foundation
import UIKit
import SpriteKit

@objc public final class WKRocketSmokeCloud: UIView {

    private let skView: SKView
    private let scene: SKScene
    private let leftEmitter: SKEmitterNode
    private let rightEmitter: SKEmitterNode
    private var cleanupTimer: Foundation.Timer?
    private var active: Bool = false

    @objc public override init(frame: CGRect) {
        self.skView = SKView(frame: CGRect(origin: .zero, size: frame.size))
        self.skView.backgroundColor = .clear
        self.skView.isOpaque = false
        self.skView.allowsTransparency = true
        self.skView.isUserInteractionEnabled = false
        self.skView.ignoresSiblingOrder = true

        self.scene = SKScene(size: frame.size)
        self.scene.backgroundColor = .clear
        self.scene.scaleMode = .resizeFill
        self.scene.anchorPoint = CGPoint(x: 0, y: 0)
        self.scene.physicsWorld.gravity = CGVector(dx: 0, dy: -0.2) // 烟雾受微弱重力下沉

        self.leftEmitter = Self.buildEmitter(isLeft: true)
        self.rightEmitter = Self.buildEmitter(isLeft: false)

        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.isUserInteractionEnabled = false
        self.addSubview(self.skView)
        self.skView.presentScene(self.scene)

        // 添加湦流场 → 烟雾自然翻滚
        let turbulence = SKFieldNode.turbulenceField(withSmoothness: 0.4, animationSpeed: 0.8)
        turbulence.strength = 1.8
        turbulence.region = SKRegion(size: frame.size) // 整个场景受扰动
        turbulence.position = CGPoint(x: frame.width / 2, y: frame.height / 2)
        self.scene.addChild(turbulence)

        // 噪声场 → 整体气流缓慢推动烟雾
        let noise = SKFieldNode.noiseField(withSmoothness: 0.6, animationSpeed: 0.5)
        noise.strength = 0.5
        noise.region = SKRegion(size: frame.size)
        noise.position = CGPoint(x: frame.width / 2, y: frame.height / 2)
        self.scene.addChild(noise)

        self.scene.addChild(self.leftEmitter)
        self.scene.addChild(self.rightEmitter)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    public override func layoutSubviews() {
        super.layoutSubviews()
        skView.frame = CGRect(origin: .zero, size: bounds.size)
        scene.size = bounds.size
    }

    deinit {
        cleanupTimer?.invalidate()
    }

    // MARK: - Public API

    /// 开始喷射烟雾（左右各一个 emitter，位于 nozzlePoint 两侧）。
    /// - Parameter nozzlePoint: UIKit 坐标（top-left 原点）的喷口位置
    /// - Parameter spread: 左右 emitter 相对 nozzle 的横向偏移
    @objc public func startEmitting(atNozzlePoint uikitPoint: CGPoint, spread: CGFloat) {
        // UIKit → SpriteKit 坐标（Y 翻转）
        let skY = bounds.height - uikitPoint.y
        self.leftEmitter.position = CGPoint(x: uikitPoint.x - spread, y: skY)
        self.rightEmitter.position = CGPoint(x: uikitPoint.x + spread, y: skY)

        self.active = true
        self.setIntensity(0.0) // 先设为 0，由外部控制
    }

    /// 设置喷射强度（0.0 ~ 2.0）：
    ///   0   → 无烟雾生成
    ///   1.0 → 蓄势阶段（温和但明显）
    ///   1.7 → 升空峰值（最猛烈）
    ///   0.55 → 发射后（衰减中）
    @objc public func setIntensity(_ intensity: CGFloat) {
        let clamped = max(0.0, min(2.0, intensity))
        // 浓度：birthRate 高系数 → 明显的白烟云
        self.leftEmitter.particleBirthRate = 90.0 * clamped
        self.rightEmitter.particleBirthRate = 90.0 * clamped
        // 速度：跟随强度加剧扰动
        let velMul: CGFloat = 0.7 + 0.8 * clamped
        self.leftEmitter.particleSpeed = 55.0 * velMul
        self.rightEmitter.particleSpeed = 55.0 * velMul
        // 粒子尺寸跟随强度增大（峰值时烟团更大）
        let scaleMul: CGFloat = 0.9 + 0.45 * clamped
        self.leftEmitter.particleScale = 1.05 * scaleMul
        self.rightEmitter.particleScale = 1.05 * scaleMul
    }

    /// 停止喷射（已有粒子继续受场力飘动，lifetime 结束后自然消失）
    @objc public func stopEmitting() {
        self.leftEmitter.particleBirthRate = 0
        self.rightEmitter.particleBirthRate = 0
        self.active = false
        self.scheduleCleanup()
    }

    // MARK: - Emitter 构造

    private static func buildEmitter(isLeft: Bool) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = SKTexture(image: Self.smokePuffImage())
        e.particleBirthRate = 0
        e.particleLifetime = 2.2
        e.particleLifetimeRange = 0.8
        e.particleSize = CGSize(width: 42, height: 42)
        e.particleScale = 0.9
        e.particleScaleRange = 0.4
        e.particleScaleSpeed = 0.55        // 飘散时膨胀
        e.particleAlpha = 0.65
        e.particleAlphaRange = 0.25
        e.particleAlphaSpeed = -0.35       // 渐渐淡出
        e.particleColor = .white
        e.particleColorBlendFactor = 1.0
        e.particleColorBlendFactorRange = 0.0
        e.particleRotation = 0
        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = isLeft ? 0.6 : -0.6
        // 发射方向：左侧朝左 (π, SK 坐标系)，右侧朝右 (0)
        // SpriteKit 角度：0=右，π/2=上。这里用 .pi 表示朝左，0 表示朝右
        e.emissionAngle = isLeft ? .pi : 0
        e.emissionAngleRange = .pi / 3      // 60° 锥角（往各个方向散开一些）
        e.particleSpeed = 38
        e.particleSpeedRange = 18
        // 关键：粒子受物理场影响（否则 SKFieldNode 不生效）
        e.fieldBitMask = 0xFFFF_FFFF
        // 粒子向下微沉
        e.yAcceleration = -20
        return e
    }

    // MARK: - 清理

    private func scheduleCleanup() {
        if cleanupTimer != nil { return }
        cleanupTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            // 当双方都不再生成，且 lifetime 已过 → 移除
            let leftIdle = self.leftEmitter.particleBirthRate == 0
            let rightIdle = self.rightEmitter.particleBirthRate == 0
            if leftIdle && rightIdle {
                // 2.2s lifetime + 0.8s range → 约 3s 后粒子全部消失
                let now = CACurrentMediaTime()
                if self.cleanupDeadline == 0 {
                    self.cleanupDeadline = now + 3.2
                }
                if now >= self.cleanupDeadline {
                    t.invalidate()
                    self.cleanupTimer = nil
                    self.removeFromSuperview()
                }
            }
        }
    }
    private var cleanupDeadline: CFTimeInterval = 0

    // MARK: - 粒子纹理（柔边白色烟团）

    private static var _smokeImage: UIImage?
    private static func smokePuffImage() -> UIImage {
        if let img = _smokeImage { return img }
        let size: CGFloat = 120
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let cs = CGColorSpaceCreateDeviceRGB()
            // 中心较浓的白 → 边缘彻底透明（柔边，叠加不会成黑块）
            let colors: CFArray = [
                UIColor(white: 1.0, alpha: 0.85).cgColor,
                UIColor(white: 1.0, alpha: 0.45).cgColor,
                UIColor(white: 1.0, alpha: 0.12).cgColor,
                UIColor(white: 1.0, alpha: 0.0).cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.35, 0.7, 1.0]
            if let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: locations) {
                cg.drawRadialGradient(gradient,
                                      startCenter: CGPoint(x: size / 2, y: size / 2), startRadius: 0,
                                      endCenter: CGPoint(x: size / 2, y: size / 2), endRadius: size / 2,
                                      options: [])
            }
        }
        _smokeImage = img
        return img
    }
}

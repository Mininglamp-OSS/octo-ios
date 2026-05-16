// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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
import simd

@objc public final class WKRocketSmokeCloud: UIView {

    private let skView: SKView
    private let scene: SKScene
    private let leftEmitter: SKEmitterNode
    private let rightEmitter: SKEmitterNode
    private let centerEmitter: SKEmitterNode    // 中心 360° 翻涌（主堆积 + 3D 感）
    private let groundEmitter: SKEmitterNode    // 底部向两侧水平扇形扩散（地面翻滚）
    // 火焰炙烤层：左右两支，分别对应 leftEmitter/rightEmitter 的喷射方向，粒子拉长并旋转 → 呈现"顺着烟雾流向的红色烟条"
    private let leftHeatEmitter: SKEmitterNode
    private let rightHeatEmitter: SKEmitterNode
    private let flameGlowSprite: SKSpriteNode   // 火焰光照层（橙红径向辐射，.add 混合叠加）
    private let leftVortex: SKFieldNode         // 左侧涡流场（发射瞬间按 nozzle 重新定位）
    private let rightVortex: SKFieldNode        // 右侧涡流场
    private var cleanupTimer: Foundation.Timer?
    private var active: Bool = false
    // 火焰炙烤粒子强度因子（0~1，外部 stopHeatEmission 调用后 0.3s 内平滑降到 0）
    private var heatLevel: CGFloat = 1.0
    private var heatFadeDisplayLink: CADisplayLink?
    private var heatFadeStart: CGFloat = 0.0
    private var heatFadeTarget: CGFloat = 0.0
    private var heatFadeStartTime: CFTimeInterval = 0.0
    private var heatFadeDuration: CFTimeInterval = 0.3

    // 强度平滑过渡
    private var currentIntensity: CGFloat = 0.0
    private var intensityDisplayLink: CADisplayLink?
    private var intensityStart: CGFloat = 0.0
    private var intensityTarget: CGFloat = 0.0
    private var intensityStartTime: CFTimeInterval = 0.0
    private var intensityDuration: CFTimeInterval = 0.0

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
        self.centerEmitter = Self.buildCenterEmitter()
        self.groundEmitter = Self.buildGroundEmitter()
        self.leftHeatEmitter = Self.buildHeatEmitter(isLeft: true)
        self.rightHeatEmitter = Self.buildHeatEmitter(isLeft: false)
        self.flameGlowSprite = Self.buildFlameGlowSprite()

        // 涡流场先创建（位置在 startEmitting 里根据 nozzle 动态调整到喷口两侧）
        let lv = SKFieldNode.vortexField()
        lv.strength = -1.2
        lv.falloff = 0.8
        lv.region = SKRegion(radius: Float(frame.width * 0.28))
        self.leftVortex = lv
        let rv = SKFieldNode.vortexField()
        rv.strength = 1.2
        rv.falloff = 0.8
        rv.region = SKRegion(radius: Float(frame.width * 0.28))
        self.rightVortex = rv

        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.isUserInteractionEnabled = false
        self.addSubview(self.skView)
        self.skView.presentScene(self.scene)

        // 湍流场（加强 strength 3.0 → 烟雾翻滚更剧烈）
        let turbulence = SKFieldNode.turbulenceField(withSmoothness: 0.35, animationSpeed: 1.0)
        turbulence.strength = 3.0
        turbulence.region = SKRegion(size: frame.size)
        turbulence.position = CGPoint(x: frame.width / 2, y: frame.height / 2)
        self.scene.addChild(turbulence)

        // 噪声场 → 缓慢整体气流
        let noise = SKFieldNode.noiseField(withSmoothness: 0.6, animationSpeed: 0.5)
        noise.strength = 0.6
        noise.region = SKRegion(size: frame.size)
        noise.position = CGPoint(x: frame.width / 2, y: frame.height / 2)
        self.scene.addChild(noise)

        // 初始默认位置（后续 startEmitting 会覆盖）
        self.leftVortex.position = CGPoint(x: frame.width * 0.30, y: frame.height * 0.20)
        self.rightVortex.position = CGPoint(x: frame.width * 0.70, y: frame.height * 0.20)
        self.scene.addChild(self.leftVortex)
        self.scene.addChild(self.rightVortex)

        self.scene.addChild(self.groundEmitter)
        self.scene.addChild(self.centerEmitter)
        self.scene.addChild(self.leftEmitter)
        self.scene.addChild(self.rightEmitter)
        // 火焰炙烤粒子层（左右两支，拉长顺向喷射）
        self.scene.addChild(self.leftHeatEmitter)
        self.scene.addChild(self.rightHeatEmitter)
        // 火焰光照层放最上层（.add 混合叠加到所有 emitter 之上 → 照亮烟雾）
        self.scene.addChild(self.flameGlowSprite)
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

    /// 开始喷射烟雾（4 个 emitter 组合：左/右两侧扩散 + 中心 360° 翻涌 + 底部向上涌）
    /// - Parameter nozzlePoint: UIKit 坐标（top-left 原点）的喷口位置
    /// - Parameter spread:      左右 emitter 相对 nozzle 的横向偏移
    @objc public func startEmitting(atNozzlePoint uikitPoint: CGPoint, spread: CGFloat) {
        // UIKit → SpriteKit 坐标（Y 翻转）
        let skY = bounds.height - uikitPoint.y
        // 左右 emitter **都从喷口出发**（不再左右偏移）→ 抛物线弧从火箭尾部同一点发散
        self.leftEmitter.position   = CGPoint(x: uikitPoint.x, y: skY)
        self.rightEmitter.position  = CGPoint(x: uikitPoint.x, y: skY)
        // 中心 emitter：**与喷口同高度**（不再下移）→ 粒子在喷口位置向上翻涌，
        // 不会在喷口下方冒出形成"朝下烟"
        self.centerEmitter.position = CGPoint(x: uikitPoint.x, y: skY)
        // 底部 emitter：略低于喷口（仅 6pt）→ 贴着基座向上+两侧翻涌
        self.groundEmitter.position = CGPoint(x: uikitPoint.x, y: skY - 6)
        // 火焰光照层：略低于喷口（模拟火焰在喷口下方燃烧照亮附近烟雾）
        self.flameGlowSprite.position = CGPoint(x: uikitPoint.x, y: skY - 10)
        self.flameGlowSprite.alpha = 0
        // 火焰炙烤粒子：都从喷口同一点出发（和 left/right emitter 相同），沿喷射方向拉长
        self.leftHeatEmitter.position  = CGPoint(x: uikitPoint.x, y: skY)
        self.rightHeatEmitter.position = CGPoint(x: uikitPoint.x, y: skY)

        // 涡流场移到屏幕两侧边缘（发射台高度）→ 烟雾扩散到边缘时被卷旋
        // 不再放在喷口两侧（避免在喷口附近就被卷向上走）
        let edgeVortexY = skY - spread * 0.6   // 边缘涡流位于发射台水平高度
        self.leftVortex.position  = CGPoint(x: bounds.width * 0.12, y: edgeVortexY)
        self.rightVortex.position = CGPoint(x: bounds.width * 0.88, y: edgeVortexY)

        self.active = true
        self.setIntensity(0.0) // 先设为 0，由外部控制
    }

    /// 设置喷射强度（0.0 ~ 2.0）：颜色、浓度、速度、尺寸联动过渡
    ///   0.0  → 无烟雾
    ///   1.0  → 蓄势阶段：浅灰白（水蒸气 + 少量燃料碳粒）
    ///   1.7  → 升空峰值：中灰（燃料充分燃烧，碳颗粒增多）
    ///   0.55 → 发射后：深灰带微蓝（冷却中的浓烟）
    ///
    /// 改 `particleColor` 只影响**新生粒子**，旧粒子保持原色 →
    /// 视觉上自然从白灰过渡到深灰，不需要显式动画。
    @objc public func setIntensity(_ intensity: CGFloat) {
        let clamped = max(0.0, min(2.0, intensity))
        self.currentIntensity = clamped

        // === 左右侧 emitter（水平扩散 — 主)===
        self.leftEmitter.particleBirthRate = 110.0 * clamped
        self.rightEmitter.particleBirthRate = 110.0 * clamped
        let velMul: CGFloat = 0.7 + 0.8 * clamped
        self.leftEmitter.particleSpeed = 60.0 * velMul
        self.rightEmitter.particleSpeed = 60.0 * velMul
        let scaleMul: CGFloat = 0.9 + 0.45 * clamped
        self.leftEmitter.particleScale = 1.1 * scaleMul
        self.rightEmitter.particleScale = 1.1 * scaleMul
        let alphaBase: CGFloat = 0.55 + 0.20 * min(clamped, 1.5)
        self.leftEmitter.particleAlpha = alphaBase
        self.rightEmitter.particleAlpha = alphaBase

        // === 中心 emitter（基座向上翻涌 — 体积堆积） ===
        // 2D 侧视场景，不尝试模拟"向镜头推进"的假 3D 效果
        self.centerEmitter.particleBirthRate = 85.0 * clamped
        self.centerEmitter.particleSpeed = 22.0 * velMul
        self.centerEmitter.particleScale = 1.0 * scaleMul
        self.centerEmitter.particleAlpha = alphaBase * 0.88

        // === 底部 emitter（贴地向上翻腾 — 起飞时的地面烟涌） ===
        self.groundEmitter.particleBirthRate = 70.0 * clamped
        self.groundEmitter.particleSpeed = 45.0 * velMul
        self.groundEmitter.particleScale = 1.35 * scaleMul
        self.groundEmitter.particleAlpha = alphaBase * 0.95

        // 颜色：4 个 emitter 统一（新生粒子同色，老粒子保留原色 → 自然过渡）
        let c = Self.smokeColorForIntensity(clamped)
        self.leftEmitter.particleColor = c
        self.rightEmitter.particleColor = c
        self.centerEmitter.particleColor = c
        self.groundEmitter.particleColor = c

        // === 火焰炙烤粒子（.add blend 橙，叠加到白烟上 → 近喷口的烟看起来橙色炙光）===
        // heatLevel 由外部 stopHeatEmission/fadeHeatLevelTo 控制
        let heatBirth: CGFloat = 55.0 * clamped * self.heatLevel
        self.leftHeatEmitter.particleBirthRate = heatBirth
        self.rightHeatEmitter.particleBirthRate = heatBirth

        // === 火焰光照层（强度随火焰变化）— 现在只提供底部辅助照亮，主色依赖 heat 粒子 ===
        //   蓄势 (1.0): alpha 0.10
        //   升空峰值 (1.7): alpha 0.22
        //   全功率 (2.0): alpha 0.28
        let glowAlpha: CGFloat = min(0.28, 0.05 + clamped * 0.12)
        self.flameGlowSprite.alpha = glowAlpha
        // 尺寸跟随强度：强度高时光照范围更大
        let glowScale: CGFloat = 0.85 + 0.5 * min(clamped, 1.8)
        self.flameGlowSprite.setScale(glowScale)
        // 颜色偏移：强度高时偏红（高温→红光）
        if clamped > 1.0 {
            let redT = min((clamped - 1.0) / 1.0, 1.0)
            // 由橙 (1.0, 0.55, 0.15) → 红橙 (1.0, 0.35, 0.10)
            self.flameGlowSprite.color = UIColor(red: 1.0,
                                                  green: 0.55 - 0.20 * redT,
                                                  blue: 0.15 - 0.05 * redT,
                                                  alpha: 1.0)
            self.flameGlowSprite.colorBlendFactor = 0.6
        } else {
            self.flameGlowSprite.colorBlendFactor = 0.0  // 用纹理本色（橙）
        }
    }

    /// 强度 → 烟雾颜色映射（健康燃料烟 = 干净白雾，全场景白度统一）
    ///   0   ~ 0.7 : 纯白 0.99 → 0.98   （点火初期水蒸气）
    ///   0.7 ~ 1.4 : 0.98 → 0.96        （推力加大极微变化）
    ///   1.4 ~ 2.0 : 0.96 → 0.94        （峰值仍是近白，不变灰）
    ///
    /// 整体全程 0.94 ~ 0.99 —— 和尾迹(0.96~1.0)/bodyWrap(0.96) 同族白度，
    /// 不会有"某些粒子明显偏灰"的违和感。
    private static func smokeColorForIntensity(_ intensity: CGFloat) -> UIColor {
        let i = max(0.0, min(2.0, intensity))
        if i < 0.7 {
            let t = i / 0.7
            let w = 0.99 - 0.01 * t         // 0.99 → 0.98
            return UIColor(white: w, alpha: 1.0)
        } else if i < 1.4 {
            let t = (i - 0.7) / 0.7
            let w = 0.98 - 0.02 * t         // 0.98 → 0.96
            return UIColor(red: w - 0.003 * t,
                           green: w - 0.001 * t,
                           blue: w + 0.002 * t,
                           alpha: 1.0)
        } else {
            let t = min((i - 1.4) / 0.6, 1.0)
            let w = 0.96 - 0.02 * t         // 0.96 → 0.94（峰值近白，绝不灰）
            return UIColor(red: w - 0.004 * t,
                           green: w - 0.002 * t,
                           blue: w + 0.003 * t,
                           alpha: 1.0)
        }
    }

    /// 平滑过渡到目标强度（CADisplayLink 每帧插值 → 颜色/密度/速度/尺寸连续变化）。
    /// - Parameter target:   目标 intensity (0.0 ~ 2.0)
    /// - Parameter duration: 过渡时长（秒）
    /// 用 easeInOut 曲线，让过渡前后都有"前奏"，不会瞬间跳变。
    @objc public func animateIntensity(to target: CGFloat, duration: TimeInterval) {
        let clampedTarget = max(0.0, min(2.0, target))
        self.intensityStart = self.currentIntensity
        self.intensityTarget = clampedTarget
        self.intensityStartTime = CACurrentMediaTime()
        self.intensityDuration = duration

        if self.intensityDisplayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(onIntensityTick))
            link.add(to: .main, forMode: .common)
            self.intensityDisplayLink = link
        }
    }

    @objc private func onIntensityTick() {
        let elapsed = CACurrentMediaTime() - self.intensityStartTime
        let t = min(elapsed / max(self.intensityDuration, 0.001), 1.0)
        let eased = Self.easeInOut(CGFloat(t))
        let value = self.intensityStart + (self.intensityTarget - self.intensityStart) * eased
        self.setIntensity(value)
        if t >= 1.0 {
            self.intensityDisplayLink?.invalidate()
            self.intensityDisplayLink = nil
        }
    }

    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 2 * t * t
        } else {
            let inv = -2 * t + 2
            return 1 - inv * inv / 2
        }
    }

    /// 停止喷射（已有粒子继续受场力飘动，lifetime 结束后自然消失）
    @objc public func stopEmitting() {
        // 停止强度过渡
        self.intensityDisplayLink?.invalidate()
        self.intensityDisplayLink = nil
        self.leftEmitter.particleBirthRate = 0
        self.rightEmitter.particleBirthRate = 0
        self.centerEmitter.particleBirthRate = 0
        self.groundEmitter.particleBirthRate = 0
        self.leftHeatEmitter.particleBirthRate = 0
        self.rightHeatEmitter.particleBirthRate = 0
        // 火焰光照淡出（0.5s）— 和火箭远离同步
        self.flameGlowSprite.removeAction(forKey: "glow-pulse")
        self.flameGlowSprite.run(SKAction.fadeOut(withDuration: 0.5))
        self.currentIntensity = 0.0
        self.active = false
        self.scheduleCleanup()
    }

    /// 平滑调整火焰炙烤粒子强度到指定目标值。
    /// - target: 目标 heatLevel (0.0 ~ 1.0)
    /// - duration: 过渡时长（秒），0 即立即生效
    /// 起飞时调用 `fadeHeatLevelTo:0 duration:1.3` → 红色在整个起飞期间逐步减退，
    /// 配合粒子短 lifetime → 呈现"离火焰越远越淡"的距离感。
    @objc public func fadeHeatLevel(to target: CGFloat, duration: TimeInterval) {
        let clampedTarget = max(0.0, min(1.0, target))
        if duration <= 0 {
            self.heatLevel = clampedTarget
            let birth = 55.0 * self.currentIntensity * self.heatLevel
            self.leftHeatEmitter.particleBirthRate = birth
            self.rightHeatEmitter.particleBirthRate = birth
            self.heatFadeDisplayLink?.invalidate()
            self.heatFadeDisplayLink = nil
            return
        }
        self.heatFadeStart = self.heatLevel
        self.heatFadeTarget = clampedTarget
        self.heatFadeDuration = duration
        self.heatFadeStartTime = CACurrentMediaTime()
        if self.heatFadeDisplayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(onHeatFadeTick))
            link.add(to: .main, forMode: .common)
            self.heatFadeDisplayLink = link
        }
    }

    /// 停止火焰炙烤粒子 —— 0.3s 快速过渡到 0（保留此 API 作为"立即关闭"的便捷入口）
    @objc public func stopHeatEmission() {
        self.fadeHeatLevel(to: 0, duration: 0.3)
    }

    /// 切换火焰炙烤粒子到"起飞模式"：拉长粒子 + 顺喷射方向 + 定向斜上发射。
    /// 起飞瞬间调用 —— 此后新生成的红粒子形态变为沿两侧喷射方向的"橙色烟条"，
    /// 已存在的圆形红粒子仍按自身 lifetime 自然淡出（无突变）。
    @objc public func configureHeatForLaunch() {
        // 左：朝左上 30°（5π/6）
        self.leftHeatEmitter.emissionAngle = 5 * .pi / 6
        self.leftHeatEmitter.emissionAngleRange = .pi / 4
        self.leftHeatEmitter.particleSize = CGSize(width: 90, height: 35)
        self.leftHeatEmitter.particleRotation = 5 * .pi / 6
        self.leftHeatEmitter.particleRotationRange = .pi / 10
        self.leftHeatEmitter.particleSpeed = 55
        self.leftHeatEmitter.particleSpeedRange = 20
        self.leftHeatEmitter.yAcceleration = -20

        // 右：朝右上 30°（π/6）
        self.rightHeatEmitter.emissionAngle = .pi / 6
        self.rightHeatEmitter.emissionAngleRange = .pi / 4
        self.rightHeatEmitter.particleSize = CGSize(width: 90, height: 35)
        self.rightHeatEmitter.particleRotation = .pi / 6
        self.rightHeatEmitter.particleRotationRange = .pi / 10
        self.rightHeatEmitter.particleSpeed = 55
        self.rightHeatEmitter.particleSpeedRange = 20
        self.rightHeatEmitter.yAcceleration = -20
    }

    @objc private func onHeatFadeTick() {
        let elapsed = CACurrentMediaTime() - self.heatFadeStartTime
        let t = min(elapsed / self.heatFadeDuration, 1.0)
        self.heatLevel = self.heatFadeStart + (self.heatFadeTarget - self.heatFadeStart) * CGFloat(t)
        // 主动更新两支 heat emitter 的 birthRate（不依赖下一次 setIntensity 调用）
        let birth = 55.0 * self.currentIntensity * self.heatLevel
        self.leftHeatEmitter.particleBirthRate = birth
        self.rightHeatEmitter.particleBirthRate = birth
        if t >= 1.0 {
            self.heatLevel = self.heatFadeTarget
            self.heatFadeDisplayLink?.invalidate()
            self.heatFadeDisplayLink = nil
        }
    }

    /// 发射瞬间的"气流冲击 + 沿边翻滚"：
    ///   1. 左右两向线性场 → 喷口附近的粒子被向两侧推开（水平爆散，**无朝下分量**）
    ///   2. 临时强湍流场 turbo  → 贴近喷口剧烈翻卷
    ///   3. 边缘向上场 edgeUpdraft → 烟雾扩散到屏幕左右边缘后沿边缘向上翻滚
    ///
    /// 关键点：不用 radialGravityField（会向四周含朝下爆散），而是**水平双向线性场**，
    /// 从根上杜绝"发射瞬间出现朝下烟雾"。
    @objc public func applyBlast(atNozzlePoint uikitPoint: CGPoint, duration: TimeInterval) {
        let skY = bounds.height - uikitPoint.y

        // === 左半区向左推（只水平，不向下） ===
        let blastLeft = SKFieldNode.linearGravityField(withVector: vector_float3(-18, 0, 0))
        blastLeft.strength = 1.2
        blastLeft.falloff = 0.5
        blastLeft.region = SKRegion(size: CGSize(width: bounds.width * 0.5,
                                                  height: bounds.height * 0.55))
        blastLeft.position = CGPoint(x: uikitPoint.x - bounds.width * 0.25, y: skY)
        blastLeft.categoryBitMask = 0xFFFF_FFFF
        scene.addChild(blastLeft)

        // === 右半区向右推（只水平，不向下） ===
        let blastRight = SKFieldNode.linearGravityField(withVector: vector_float3(18, 0, 0))
        blastRight.strength = 1.2
        blastRight.falloff = 0.5
        blastRight.region = SKRegion(size: CGSize(width: bounds.width * 0.5,
                                                   height: bounds.height * 0.55))
        blastRight.position = CGPoint(x: uikitPoint.x + bounds.width * 0.25, y: skY)
        blastRight.categoryBitMask = 0xFFFF_FFFF
        scene.addChild(blastRight)

        // 水平爆散场衰减：前 50% 保持峰值，后 50% 线性衰减至 0
        let makeHorizontalDecay = { () -> SKAction in
            return SKAction.customAction(withDuration: duration) { node, elapsed in
                let t = elapsed / CGFloat(duration)
                if let f = node as? SKFieldNode {
                    if t > 0.5 {
                        f.strength = Float(1.2 * (1.0 - (t - 0.5) * 2.0))
                    }
                }
            }
        }
        blastLeft.run(SKAction.sequence([makeHorizontalDecay(), SKAction.removeFromParent()]))
        blastRight.run(SKAction.sequence([makeHorizontalDecay(), SKAction.removeFromParent()]))

        // === 临时强湍流场（贴近喷口剧烈翻卷） ===
        let turbo = SKFieldNode.turbulenceField(withSmoothness: 0.20, animationSpeed: 2.8)
        turbo.strength = 5.0
        turbo.falloff = 0.5
        turbo.region = SKRegion(radius: Float(bounds.width * 0.60))
        turbo.position = CGPoint(x: uikitPoint.x, y: skY - 10.0)
        turbo.categoryBitMask = 0xFFFF_FFFF
        scene.addChild(turbo)

        let turboDuration = duration * 2.2
        let turboDecay = SKAction.customAction(withDuration: turboDuration) { node, elapsed in
            let t = elapsed / CGFloat(turboDuration)
            if let f = node as? SKFieldNode {
                f.strength = Float(5.0 * (1.0 - t))
            }
        }
        turbo.run(SKAction.sequence([turboDecay, SKAction.removeFromParent()]))

        // === 左/右边缘"空气自然扰动"场 ===
        // 经过几轮试验发现：任何定向场力（向上、向内）都会被感知为"有力量在拉/推"粒子，
        // 不自然。正确做法 —— **只保留湍流（随机扰动）**，模拟真实空气在屏幕边缘的
        // 自然流动。粒子飘到边缘时会被轻微打散、方向各异，就像被气流吹散了一样，
        // 不会出现"一股力拽它上天"或"往回堆"的观感。
        let edgeDelay: TimeInterval = 1.0
        let fadeInDur: TimeInterval = 0.6
        let holdDur: TimeInterval = 0.7
        let fadeOutDur: TimeInterval = 0.5
        let peakTurbStrength: Float = 1.8          // 湍流强度 — 温和的空气扰动

        // — 左边缘湍流 —
        let leftEdgeTurb = SKFieldNode.turbulenceField(withSmoothness: 0.6, animationSpeed: 0.8)
        leftEdgeTurb.strength = 0
        leftEdgeTurb.falloff = 0.2
        leftEdgeTurb.region = SKRegion(size: CGSize(width: bounds.width * 0.22,
                                                      height: bounds.height))
        leftEdgeTurb.position = CGPoint(x: bounds.width * 0.08, y: bounds.height * 0.5)
        leftEdgeTurb.categoryBitMask = 0xFFFF_FFFF
        scene.addChild(leftEdgeTurb)

        // — 右边缘湍流 —
        let rightEdgeTurb = SKFieldNode.turbulenceField(withSmoothness: 0.6, animationSpeed: 0.8)
        rightEdgeTurb.strength = 0
        rightEdgeTurb.falloff = 0.2
        rightEdgeTurb.region = SKRegion(size: CGSize(width: bounds.width * 0.22,
                                                       height: bounds.height))
        rightEdgeTurb.position = CGPoint(x: bounds.width * 0.92, y: bounds.height * 0.5)
        rightEdgeTurb.categoryBitMask = 0xFFFF_FFFF
        scene.addChild(rightEdgeTurb)

        // 延迟激活 + 缓起 + 保持 + 缓退
        let makeEdgeFade = { (peak: Float) -> SKAction in
            let fadeIn = SKAction.customAction(withDuration: fadeInDur) { node, elapsed in
                if let f = node as? SKFieldNode {
                    f.strength = peak * Float(elapsed / fadeInDur)
                }
            }
            let hold = SKAction.customAction(withDuration: holdDur) { node, _ in
                if let f = node as? SKFieldNode { f.strength = peak }
            }
            let fadeOut = SKAction.customAction(withDuration: fadeOutDur) { node, elapsed in
                if let f = node as? SKFieldNode {
                    f.strength = peak * Float(1.0 - elapsed / fadeOutDur)
                }
            }
            return SKAction.sequence([
                SKAction.wait(forDuration: edgeDelay),
                fadeIn,
                hold,
                fadeOut,
                SKAction.removeFromParent()
            ])
        }
        leftEdgeTurb.run(makeEdgeFade(peakTurbStrength))
        rightEdgeTurb.run(makeEdgeFade(peakTurbStrength))

        // （底部向上场已移除：左右 emitter 现在上抛发射，1.5s lifetime 内粒子到不了屏幕底部，
        //   bottomEdgeUp 已无粒子可作用。）

        // === 喷口两侧的局部小涡旋（短寿命，让喷口附近烟团内部翻卷） ===
        // 发射瞬间加强蓄势烟团的自转感，0.8s 后自然衰减消失
        let localVortexDuration: TimeInterval = 0.8
        let makeLocalVortex = { (sign: CGFloat) -> SKFieldNode in
            let v = SKFieldNode.vortexField()
            v.strength = Float(sign * 2.6)
            v.falloff = 1.0
            v.region = SKRegion(radius: Float(self.bounds.width * 0.18))
            v.position = CGPoint(x: uikitPoint.x + sign * self.bounds.width * 0.12, y: skY - 6.0)
            v.categoryBitMask = 0xFFFF_FFFF
            v.userData = NSMutableDictionary(dictionary: ["sign": NSNumber(value: Float(sign))])
            return v
        }
        let lvLocal = makeLocalVortex(-1.0)
        let rvLocal = makeLocalVortex(1.0)
        scene.addChild(lvLocal)
        scene.addChild(rvLocal)
        let localVortexDecay = SKAction.customAction(withDuration: localVortexDuration) { node, elapsed in
            let t = elapsed / CGFloat(localVortexDuration)
            if let f = node as? SKFieldNode {
                let sign = (f.userData?["sign"] as? NSNumber)?.floatValue ?? 1.0
                f.strength = sign * Float(2.6 * (1.0 - t))
            }
        }
        lvLocal.run(SKAction.sequence([localVortexDecay, SKAction.removeFromParent()]))
        rvLocal.run(SKAction.sequence([localVortexDecay, SKAction.removeFromParent()]))

        // 火焰光照层同步脉冲（发射瞬间爆亮）
        let currentAlpha = self.flameGlowSprite.alpha
        let peakAlpha = min(0.65, currentAlpha * 1.8)
        let glowPulse = SKAction.sequence([
            SKAction.fadeAlpha(to: peakAlpha, duration: 0.15),
            SKAction.fadeAlpha(to: currentAlpha, duration: duration - 0.15)
        ])
        self.flameGlowSprite.run(glowPulse, withKey: "glow-pulse")
    }

    // MARK: - Emitter 构造

    private static func buildEmitter(isLeft: Bool) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = SKTexture(image: Self.smokePuffImage())
        e.particleBirthRate = 0
        e.particleLifetime = 1.5            // 原 2.2 → 1.5（配合 stopEmitting 后快速清空）
        e.particleLifetimeRange = 0.5
        e.particleSize = CGSize(width: 42, height: 42)
        e.particleScale = 0.9
        e.particleScaleRange = 0.4
        e.particleScaleSpeed = 0.55        // 飘散时膨胀
        e.particleAlpha = 0.65
        e.particleAlphaRange = 0.25
        e.particleAlphaSpeed = -0.55       // 原 -0.35 → -0.55（更快淡出 → ~1.2s 内消失）
        e.particleColor = .white
        e.particleColorBlendFactor = 1.0
        e.particleColorBlendFactorRange = 0.0
        e.particleRotation = 0
        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = isLeft ? 0.6 : -0.6
        // 发射方向：**从喷口向上偏外侧** → 配合重力形成抛物线弧 →
        // 从火箭尾部向左右两侧以弧形喷射（不再是直线水平喷射）。
        //   leftEmitter  → 5π/6（150°，水平偏上 30°）
        //   rightEmitter → π/6（30°，水平偏上 30°）
        //   emissionAngleRange = π/4（45° 锥角，全部位于水平线以上）
        e.emissionAngle = isLeft ? (5 * .pi / 6) : (.pi / 6)
        e.emissionAngleRange = .pi / 4
        e.particleSpeed = 60                // 原 38 → 60，让粒子能飞到屏幕边缘
        e.particleSpeedRange = 18
        // 关键：粒子受物理场影响（否则 SKFieldNode 不生效）
        e.fieldBitMask = 0xFFFF_FFFF
        // yAcceleration = -20：重力下拉 → 粒子弧形轨迹，做到"喷上去-飘远-落下"的抛物线
        // 粒子初速向上有分量 → 即便受重力，整个 1.5s lifetime 内不会掉到喷口下方
        e.yAcceleration = -20
        return e
    }

    /// 中心 emitter：**火箭尾部基座的向上翻涌烟团**（2D 侧视）。
    /// 真实 2D 侧视场景里没有"深度"轴 —— 不尝试模拟"向观察者涌来"；
    /// 只是在喷口附近生成一团向上/向两侧翻滚的烟，和左右水平 emitter 一起堆出基座烟团体积。
    private static func buildCenterEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = SKTexture(image: Self.smokePuffImage())
        e.particleBirthRate = 0
        e.particleLifetime = 1.3            // 原 2.0 → 1.3
        e.particleLifetimeRange = 0.4
        e.particleSize = CGSize(width: 60, height: 60)
        e.particleScale = 1.0
        e.particleScaleRange = 0.35
        e.particleScaleSpeed = 0.7          // 正常膨胀速度（取消原 1.4 的假 3D 放大）
        e.particleAlpha = 0.55
        e.particleAlphaRange = 0.18
        e.particleAlphaSpeed = -0.60        // 原 -0.42 → -0.60（更快淡出）
        e.particleColor = .white
        e.particleColorBlendFactor = 1.0
        e.particleRotation = 0
        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = 0.9
        e.emissionAngle = .pi / 2           // 朝上
        e.emissionAngleRange = .pi          // 上半圆（0° ~ π，仅朝上与水平，不含朝下）
        e.particleSpeed = 22                // 适中速度（原 12 太低会让粒子原地堆积，再被膨胀放大 → 假 3D）
        e.particleSpeedRange = 12
        e.fieldBitMask = 0xFFFF_FFFF
        e.yAcceleration = 0
        return e
    }

    /// 底部 emitter：在"地面"贴地向两侧水平扇形扩散（不再向上喷！）
    /// → 模拟火箭推力冲击地面后，烟雾沿地面向外翻滚扩散的形态。
    ///   粒子受向下微重力 + 湍流 → 在地面附近翻滚，不会升上天空。
    private static func buildGroundEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = SKTexture(image: Self.smokePuffImage())
        e.particleBirthRate = 0
        e.particleLifetime = 1.5            // 原 2.6 → 1.5
        e.particleLifetimeRange = 0.5
        e.particleSize = CGSize(width: 48, height: 48)
        e.particleScale = 1.3
        e.particleScaleRange = 0.4
        e.particleScaleSpeed = 1.1          // 极快膨胀（地面烟团）
        e.particleAlpha = 0.62
        e.particleAlphaRange = 0.20
        e.particleAlphaSpeed = -0.55        // 原 -0.28 → -0.55（更快淡出）
        e.particleColor = .white
        e.particleColorBlendFactor = 1.0
        e.particleRotation = 0
        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = 0.7
        // 水平+向上扩散：emissionAngle = π/2（朝上），emissionAngleRange = π
        //   → 覆盖上半圆（0° 朝右 ~ π 朝左，含正上），**不含正下方向**
        //   配合 groundEmitter 位于喷口下方的位置，视觉上是从"地面往上/两侧翻涌"，
        //   不再出现"尾部垂直向下"的不合理烟柱。
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = .pi
        e.particleSpeed = 55
        e.particleSpeedRange = 25
        e.fieldBitMask = 0xFFFF_FFFF
        // yAcceleration = 0：不再向下拉（原 -18 的重力会让水平粒子随时间下沉汇聚为"向下烟柱"）
        e.yAcceleration = 0
        return e
    }

    /// 火焰炙烤粒子层（左右两支）：
    /// - **默认构造（蓄势阶段）**：圆形粒子、朝上泛起 → 模拟"火焰炙烤静止烟雾"的静态泛红
    /// - **起飞后**：由 configureHeatForLaunch() 切换为拉长粒子、顺喷射方向发射 → 顺烟条状
    /// .add blend + 短寿命 → 红粒子和白烟叠加出橙色炙光，飘远前就淡出。
    private static func buildHeatEmitter(isLeft: Bool) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = SKTexture(image: Self.smokePuffImage())
        e.particleBirthRate = 0
        e.particleLifetime = 0.4
        e.particleLifetimeRange = 0.15
        // 默认：**偏圆形** — 蓄势阶段从喷口泛起
        e.particleSize = CGSize(width: 60, height: 60)
        e.particleScale = 1.0
        e.particleScaleRange = 0.25
        e.particleScaleSpeed = 1.2
        e.particleAlpha = 0.32
        e.particleAlphaRange = 0.10
        e.particleAlphaSpeed = -1.4
        e.particleColor = UIColor(red: 1.0, green: 0.55, blue: 0.22, alpha: 1.0)
        e.particleColorBlendFactor = 1.0
        e.particleBlendMode = .add
        // 默认：随机旋转（圆形粒子无方向性）
        e.particleRotation = 0
        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = 0
        // 默认：朝上泛起，范围覆盖上半圆（蓄势阶段没有定向喷射）
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = .pi
        e.particleSpeed = 30                // 低速 → 粒子泛起后就近淡出
        e.particleSpeedRange = 15
        e.fieldBitMask = 0xFFFF_FFFF
        e.yAcceleration = 0
        // 左右 emitter 初始配置相同，configureHeatForLaunch 时分别切到 150°/30°
        _ = isLeft
        return e
    }

    /// 火焰光照层：椭圆径向渐变纹理（橙色中心 → 透明边缘），.add 混合叠加到烟雾上
    /// 跟随 intensity 动态改变 alpha 和 scale，模拟火焰对附近烟雾的照亮
    private static func buildFlameGlowSprite() -> SKSpriteNode {
        let size: CGFloat = 200
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let cs = CGColorSpaceCreateDeviceRGB()
            // 中心亮橙 → 中层橙红 → 边缘透明
            let colors: CFArray = [
                UIColor(red: 1.0, green: 0.60, blue: 0.20, alpha: 1.0).cgColor,  // 中心亮橙
                UIColor(red: 1.0, green: 0.40, blue: 0.12, alpha: 0.55).cgColor, // 中层橙红
                UIColor(red: 0.85, green: 0.18, blue: 0.05, alpha: 0.12).cgColor, // 边缘深红
                UIColor(red: 0.70, green: 0.10, blue: 0.02, alpha: 0.0).cgColor,  // 完全透明
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.35, 0.75, 1.0]
            if let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: locations) {
                cg.drawRadialGradient(gradient,
                                      startCenter: CGPoint(x: size / 2, y: size / 2), startRadius: 0,
                                      endCenter: CGPoint(x: size / 2, y: size / 2), endRadius: size / 2,
                                      options: [])
            }
        }
        let texture = SKTexture(image: img)
        let sprite = SKSpriteNode(texture: texture)
        sprite.blendMode = .add             // 叠加混合 → 真实光照感
        sprite.alpha = 0                    // 初始不显示
        // 非对称 size：纵向更长（火焰从喷口向下喷射 → 照亮区域也是竖椭圆）
        sprite.size = CGSize(width: 150, height: 210)
        return sprite
    }

    // MARK: - 清理

    private func scheduleCleanup() {
        if cleanupTimer != nil { return }
        cleanupTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            // 当双方都不再生成，且 lifetime 已过 → 移除
            let leftIdle = self.leftEmitter.particleBirthRate == 0
            let rightIdle = self.rightEmitter.particleBirthRate == 0
            let centerIdle = self.centerEmitter.particleBirthRate == 0
            let groundIdle = self.groundEmitter.particleBirthRate == 0
            if leftIdle && rightIdle && centerIdle && groundIdle {
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

// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConfettiView.swift
//  WuKongBase
//
//  基于 Telegram-iOS `submodules/ConfettiEffect/Sources/ConfettiView.swift` 移植，
//  保留完整的 2D 物理模拟（重力、质量、角速度、湍流、减速相位），
//  但去掉对 TelegramUtils/Display 模块的依赖，改用自包含的 CADisplayLink 与
//  UIGraphicsImageRenderer 实现。对外仅暴露 @objc API 供 Objective-C 调用。

import Foundation
import UIKit

private struct CVVector2 {
    var x: Float
    var y: Float
}

private final class CVParticleLayer: CALayer {
    let mass: Float
    var velocity: CVVector2
    var angularVelocity: Float
    var rotationAngle: Float = 0.0
    var localTime: Float = 0.0
    var type: Int

    init(image: CGImage, size: CGSize, position: CGPoint, mass: Float, velocity: CVVector2, angularVelocity: Float, type: Int) {
        self.mass = mass
        self.velocity = velocity
        self.angularVelocity = angularVelocity
        self.type = type

        super.init()

        self.contents = image
        self.bounds = CGRect(origin: .zero, size: size)
        self.position = position
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func action(forKey event: String) -> CAAction? {
        return NSNull()
    }
}

@objc public final class WKConfettiView: UIView {

    private var particles: [CVParticleLayer] = []
    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval = 0
    private var localTime: Float = 0.0
    private var slowdownStartTimestamps: [Float?] = [nil, nil, nil]

    /// 用自定义图片作为粒子（比如贴纸图），会被染成多种颜色。
    @objc public init(frame: CGRect, customImage: UIImage?) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.setupParticles(customImage: customImage)
        self.startDisplayLink()
    }

    /// 默认圆形+长条形彩色纸屑。
    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.setupParticles(customImage: nil)
        self.startDisplayLink()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
    }

    // MARK: - Setup

    private func setupParticles(customImage: UIImage?) {
        let colors: [UIColor] = [
            UIColor(red: 0x56/255.0, green: 0xCE/255.0, blue: 0x6B/255.0, alpha: 1.0),
            UIColor(red: 0xCD/255.0, green: 0x89/255.0, blue: 0xD0/255.0, alpha: 1.0),
            UIColor(red: 0x1E/255.0, green: 0x9A/255.0, blue: 0xFF/255.0, alpha: 1.0),
            UIColor(red: 0xFF/255.0, green: 0x87/255.0, blue: 0x24/255.0, alpha: 1.0),
        ]
        let defaultDotSize = CGSize(width: 8.0, height: 8.0)
        var images: [(CGImage, CGSize)] = []

        if let customImage = customImage, let _ = customImage.cgImage {
            // 用自定义图（通常是贴纸）— 原色 + 3 种染色变体，保留风格又有彩色感
            if let cg = customImage.cgImage {
                images.append((cg, customImage.size))
            }
            for color in colors.prefix(3) {
                if let tinted = Self.tintedImage(customImage, color: color)?.cgImage {
                    images.append((tinted, customImage.size))
                }
            }
        } else {
            // 默认：4 种形状 × 4 种颜色，涵盖圆点 / 短条 / 中条 / 长条，
            // 与 scale 0.8~1.6 的随机缩放叠加产生自然长短差异
            let shapeSizes: [CGSize] = [
                CGSize(width: 8.0, height: 8.0),   // 圆点
                CGSize(width: 2.0, height: 6.0),   // 短条
                CGSize(width: 2.0, height: 10.0),  // 中条
                CGSize(width: 2.0, height: 14.0),  // 长条
            ]
            for (idx, spriteSize) in shapeSizes.enumerated() {
                for color in colors {
                    if idx == 0 {
                        if let circle = Self.filledCircleImage(diameter: spriteSize.width, color: color)?.cgImage {
                            images.append((circle, spriteSize))
                        }
                    } else {
                        if let stripe = Self.stripeImage(size: spriteSize, color: color)?.cgImage {
                            images.append((stripe, spriteSize))
                        }
                    }
                }
            }
        }

        guard !images.isEmpty else { return }
        let imageCount = images.count

        let frameWidth = self.bounds.width
        let frameHeight = self.bounds.height
        let angularVelocityRange: Range<Float> = 1.0..<6.0
        let sizeVariation: Range<Float> = 0.8..<1.6

        // 左右两侧喷射的 80×2 个粒子（数量是原来的两倍，去掉顶部下落粒子）
        let sideMassRange: Range<Float> = 110.0..<120.0
        let sideOriginYBase: Float = Float(frameHeight * 9.0 / 10.0)
        let sideOriginVelocityValueRange: Range<Float> = 1.5..<1.8
        let sideOriginVelocityValueScaling: Float = 2400.0 * Float(frameHeight) / 896.0
        let sideOriginVelocityBase: Float = Float.pi / 2.0 + atanf(Float(CGFloat(sideOriginYBase) / (frameWidth * 0.8)))
        let sideOriginVelocityVariation: Float = 0.09
        let sideOriginVelocityAngleRange: Range<Float> =
            (sideOriginVelocityBase - sideOriginVelocityVariation)..<(sideOriginVelocityBase + sideOriginVelocityVariation)
        let originAngleRange: Range<Float> = 0.0..<(Float.pi * 2.0)
        let originAmplitudeDiameter: CGFloat = 230.0
        let originAmplitudeRange: Range<Float> = 0.0..<Float(originAmplitudeDiameter / 2.0)

        let sideTypes: [Int] = [0, 1, 2]

        for sideIndex in 0..<2 {
            let sideSign: Float = sideIndex == 0 ? 1.0 : -1.0
            let baseOriginX: CGFloat = sideIndex == 0
                ? -originAmplitudeDiameter / 2.0
                : (frameWidth + originAmplitudeDiameter / 2.0)

            for i in 0..<80 {
                let originAngle = Float.random(in: originAngleRange)
                let originAmplitude = Float.random(in: originAmplitudeRange)
                let originX = baseOriginX + CGFloat(cosf(originAngle) * originAmplitude)
                let originY = CGFloat(sideOriginYBase + sinf(originAngle) * originAmplitude)

                let velocityValue = Float.random(in: sideOriginVelocityValueRange) * sideOriginVelocityValueScaling
                let velocityAngle = Float.random(in: sideOriginVelocityAngleRange)
                let velocityX = sideSign * velocityValue * sinf(velocityAngle)
                let velocityY = velocityValue * cosf(velocityAngle)
                let (image, size) = images[i % imageCount]
                let sizeScale = CGFloat(Float.random(in: sizeVariation))
                let particle = CVParticleLayer(
                    image: image,
                    size: CGSize(width: size.width * sizeScale, height: size.height * sizeScale),
                    position: CGPoint(x: originX, y: originY),
                    mass: Float.random(in: sideMassRange),
                    velocity: CVVector2(x: velocityX, y: velocityY),
                    angularVelocity: Float.random(in: angularVelocityRange),
                    type: sideTypes[i % 3]
                )
                self.particles.append(particle)
                self.layer.addSublayer(particle)
            }
        }
    }

    // MARK: - Display link

    private func startDisplayLink() {
        self.previousTimestamp = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(onDisplayLink))
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    @objc private func onDisplayLink() {
        let now = CACurrentMediaTime()
        let dt = now - self.previousTimestamp
        self.previousTimestamp = now
        self.step(dt: dt)
    }

    // MARK: - Physics step (来自 Telegram ConfettiView.step)

    private func step(dt: Double) {
        let dt = Float(dt)
        self.slowdownStartTimestamps[0] = 0.33

        var haveParticlesAboveGround = false
        let maxPositionY = self.bounds.height + 30.0

        let typeDelays: [Float] = [0.0, 0.01, 0.08]
        var dtAndDamping: [(Float, Float)] = []

        for i in 0..<3 {
            let typeDelay = typeDelays[i]
            let currentTime = self.localTime - typeDelay
            if currentTime < 0.0 {
                dtAndDamping.append((0.0, 1.0))
            } else if let slowdownStart = self.slowdownStartTimestamps[i] {
                let slowdownDt: Float
                let slowdownDuration: Float = 0.7
                let damping: Float
                if currentTime >= slowdownStart && currentTime <= slowdownStart + slowdownDuration {
                    let slowdownTimestamp: Float = currentTime - slowdownStart
                    let slowdownRampInDuration: Float = 0.05
                    let slowdownRampOutDuration: Float = 0.2
                    let rawSlowdownT: Float
                    if slowdownTimestamp < slowdownRampInDuration {
                        rawSlowdownT = slowdownTimestamp / slowdownRampInDuration
                    } else if slowdownTimestamp >= slowdownDuration - slowdownRampOutDuration {
                        let reverseTransition = (slowdownTimestamp - (slowdownDuration - slowdownRampOutDuration)) / slowdownRampOutDuration
                        rawSlowdownT = 1.0 - reverseTransition
                    } else {
                        rawSlowdownT = 1.0
                    }
                    let slowdownTransition = rawSlowdownT * rawSlowdownT
                    let slowdownFactor: Float = 0.8 * slowdownTransition + 1.0 * (1.0 - slowdownTransition)
                    slowdownDt = dt * slowdownFactor
                    let dampingFactor: Float = 0.937 * slowdownTransition + 1.0 * (1.0 - slowdownTransition)
                    damping = dampingFactor
                } else {
                    slowdownDt = dt
                    damping = 1.0
                }
                dtAndDamping.append((slowdownDt, damping))
            } else {
                dtAndDamping.append((dt, 1.0))
            }
        }
        self.localTime += dt

        let g = CVVector2(x: 0.0, y: 9.8)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var turbulenceVariation: [Float] = []
        for _ in 0..<20 {
            turbulenceVariation.append(Float.random(in: -16.0..<16.0) * 60.0)
        }
        let turbulenceVariationCount = turbulenceVariation.count
        var index = 0

        var typesWithPositiveVelocity: [Bool] = [false, false, false]

        for particle in self.particles {
            let (localDt, _) = dtAndDamping[particle.type]
            if localDt.isZero {
                continue
            }
            let damping: Float = 0.93

            particle.localTime += localDt

            var position = particle.position
            position.x += CGFloat(particle.velocity.x * localDt)
            position.y += CGFloat(particle.velocity.y * localDt)
            particle.position = position

            particle.rotationAngle += particle.angularVelocity * localDt
            particle.transform = CATransform3DMakeRotation(CGFloat(particle.rotationAngle), 0.0, 0.0, 1.0)

            let acceleration = g
            var velocity = particle.velocity
            velocity.x += acceleration.x * particle.mass * localDt
            velocity.y += acceleration.y * particle.mass * localDt
            if velocity.y < 0.0 {
                velocity.x *= damping
                velocity.y *= damping
            } else {
                velocity.x += turbulenceVariation[index % turbulenceVariationCount] * localDt
                typesWithPositiveVelocity[particle.type] = true
            }
            particle.velocity = velocity

            index += 1

            if position.y < maxPositionY {
                haveParticlesAboveGround = true
            }
        }
        for i in 0..<3 {
            if typesWithPositiveVelocity[i] && self.slowdownStartTimestamps[i] == nil {
                self.slowdownStartTimestamps[i] = max(0.0, self.localTime - typeDelays[i])
            }
        }
        CATransaction.commit()
        if !haveParticlesAboveGround {
            self.displayLink?.invalidate()
            self.displayLink = nil
            self.removeFromSuperview()
        }
    }

    // MARK: - Image helpers (self-contained, 不依赖 TelegramUtils)

    private static func filledCircleImage(diameter: CGFloat, color: UIColor) -> UIImage? {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(color.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func stripeImage(size: CGSize, color: UIColor) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(color.cgColor)
            c.fillEllipse(in: CGRect(x: 0, y: 0, width: size.width, height: size.width))
            c.fillEllipse(in: CGRect(x: 0, y: size.height - size.width, width: size.width, height: size.width))
            c.fill(CGRect(x: 0, y: size.width / 2.0, width: size.width, height: size.height - size.width))
        }
    }

    private static func tintedImage(_ image: UIImage, color: UIColor) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: image.size)
            let c = ctx.cgContext
            image.draw(in: rect)
            c.setBlendMode(.sourceIn)
            c.setFillColor(color.cgColor)
            c.fill(rect)
        }
    }
}

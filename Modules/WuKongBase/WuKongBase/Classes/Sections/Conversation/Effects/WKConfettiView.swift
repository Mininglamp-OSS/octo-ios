// Copyright 2026 MININGLAMP. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
// WKConfettiView
// --------------
// 🎉 / 🎊 表情触发的彩纸礼花效果。
//
// 视觉链路：
//   1. 自绘"半透明红色彩纸球 + 顶部 🎀 蝴蝶结 + 金色飘带"（详见
//      makeConfettiBall）
//   2. drop-in → 蓄势 → 爆开（闪光 + 冲击环 + 球身淡出）
//   3. 自写 CAEmitterLayer 瞬发 ~120 片混合形状（矩形 / 星 / 三角）粒子，
//      初始 360° 任意方向，重力随时间渐升 → 真实抛物线下落
//   4. 同步播 confetti.mp3（爆裂声）+ cheer_short.m4a（全场欢呼）
//
// 公共 OC 调用面：init(frame:customImage:) / init(frame:)，上层
// WKPartyEffect.m 零改动。
//
// 第三方资源：
//   - SwiftConfettiView (MIT) — 仅复用其 pod bundle 里的 confetti.mp3
//     爆裂声资产；粒子系统是本类自写 CAEmitterLayer，不走该库
//   - cheer_short.m4a — CC0 公有领域 (Freesound.org #511788 by kinoton)，
//     裁前 2.10s 编为 AAC m4a
//   详见 NOTICE。

import Foundation
import UIKit
import AVFoundation
import SwiftConfettiView

@objc public final class WKConfettiView: UIView {

    private let customImage: UIImage?
    private var didStart = false

    // 自写 CAEmitterLayer 瞬发 + 重力渐升 = 真物理下落（不依赖 SwiftConfettiView
    // 库的粒子系统，仅复用其 confetti.mp3 资产做爆裂声）
    private var customBurstEmitter: CAEmitterLayer?
    private var burstAudioPlayer: AVAudioPlayer?
    private var cheerAudioPlayer: AVAudioPlayer?

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
            startConfettiBurst()
        } else if superview == nil, didStart {
            customBurstEmitter?.birthRate = 0
        }
    }

    // MARK: - 自写 CAEmitterLayer 物理 burst（替代 SwiftConfettiView）
    //
    // 为什么不用 SwiftConfettiView：
    //   1) 它的 burst 内部 `max(burstCount/birthRate, 0.5)` 强制最少 0.5s 发射 →
    //      球已经炸开消失了粒子还在喷，违和。
    //   2) 它把 spread 直接给 emitterCell.emissionRange，但 emissionLongitude 是
    //      硬编码下行，无法做真正"爆开 360° 后受重力"的弹道。
    //
    // 自写方案：
    //   - 0.08s 高密度发射后 birthRate 归零 → 真·瞬发
    //   - emissionLongitude=-π/2 (向上) + emissionRange=2π → 360° 随机初始方向
    //   - 初始 yAcceleration=0 → 粒子按真初速度自由飞（部分向上飘起）
    //   - yAcceleration 在头 0.2s 从 0 渐升到 550 → 重力慢慢"接管"，向上的粒子
    //     自然减速 → 抛物线顶点 → 加速下落，符合真实纸片轻飘飘的物理感
    //   - 3 种形状（rect / star / triangle）× 6 种颜色 = 18 个 cell，shape×color 混发
    //
    // 时间线：
    //   t=0      自绘球出现在顶部（同前）
    //   t=0–0.20 drop-in spring
    //   t=0.25–0.35 蓄势 scale 1.08
    //   t=0.35   ★ BURST：球身消失 + 12 块碎片 + 冲击环 + CAEmitter 启动
    //   t=0.35–0.43  CAEmitter 高 birthRate 喷射（瞬发期）
    //   t=0.43   birthRate=0，停止发射 ← 球已没，无新粒子产生
    //   t=0.43–~5 已发射粒子继续物理演化：初始飞行 → 重力接管 → 抛物线 → 下落
    //   t=6.5    layer 整体清理

    private func startConfettiBurst() {
        let ballDiameter: CGFloat = 64
        let topInset = max(safeAreaInsets.top + 30, 80)
        let ballCenter = CGPoint(x: bounds.midX, y: bounds.minY + topInset)

        // 自绘彩带球（纸糊球质感）
        let ball = makeConfettiBall(diameter: ballDiameter, center: ballCenter)
        addSubview(ball)
        bringSubviewToFront(ball)

        ball.transform = CGAffineTransform(translationX: 0, y: -20)
            .scaledBy(x: 0.3, y: 0.3)
        ball.alpha = 0

        // drop-in
        UIView.animate(
            withDuration: 0.20,
            delay: 0,
            usingSpringWithDamping: 0.62,
            initialSpringVelocity: 0,
            options: []
        ) {
            ball.alpha = 1
            ball.transform = .identity
        } completion: { _ in
            // 蓄势
            UIView.animate(
                withDuration: 0.10,
                delay: 0.05,
                options: [.curveEaseInOut]
            ) {
                ball.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            } completion: { _ in
                self.performBurst(ball: ball, at: ballCenter)
                self.triggerCustomBurst(at: ballCenter)
            }
        }
    }

    /// 自写的 CAEmitterLayer 物理爆开。
    private func triggerCustomBurst(at origin: CGPoint) {
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterPosition = origin
        emitter.emitterShape = .point
        emitter.renderMode = .unordered
        emitter.beginTime = CACurrentMediaTime()

        let cells = makeCustomBurstCells()
        emitter.emitterCells = cells
        layer.addSublayer(emitter)
        customBurstEmitter = emitter

        // 同步播一下"啵"的爆裂声（声音资产复用 SwiftConfettiView pod 自带的 confetti.mp3，MIT）
        playBurstSound()
        // 叠加"全场欢呼"短音（前 2.10s 裁剪，CC0 公有领域，作者 kinoton @ Freesound.org #511788）
        playCheerSound()

        // 重力渐升：每个 cell 单独绑动画到 emitterCells.<name>.yAcceleration
        // t=0       0   （自由飞行 → 部分粒子可往上飘）
        // t=0.02   200  （刚开始有"轻轻往下拽"的感觉）
        // t=0.20   550  （重力主导，向上粒子被减速）
        // t=1.0    700  （稳态加速下落）
        for cell in cells {
            guard let name = cell.name else { continue }
            let gravity = CAKeyframeAnimation(keyPath: "emitterCells.\(name).yAcceleration")
            gravity.duration = 4.5
            gravity.keyTimes = [0, 0.02, 0.20, 1.0]
            gravity.values = [0, 200, 550, 700]
            gravity.fillMode = .forwards
            gravity.isRemovedOnCompletion = false
            emitter.add(gravity, forKey: "gravity_\(name)")
        }

        // 0.08s 后整体 birthRate=0 → 不再生成新粒子，已生成的继续物理演化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak emitter] in
            emitter?.birthRate = 0
        }

        // 6.5s 后清理 layer
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) { [weak self, weak emitter] in
            emitter?.removeFromSuperlayer()
            if self?.customBurstEmitter === emitter {
                self?.customBurstEmitter = nil
            }
        }
    }

    private func makeCustomBurstCells() -> [CAEmitterCell] {
        let palette = Self.ballPalette
        let shapes: [(name: String, image: UIImage)] = [
            ("rect",     Self.rectParticleImage),
            ("star",     Self.starParticleImage),
            ("triangle", Self.triangleParticleImage),
        ]

        var cells: [CAEmitterCell] = []
        for shape in shapes {
            for (colorIdx, color) in palette.enumerated() {
                let cell = CAEmitterCell()
                cell.name = "\(shape.name)_\(colorIdx)"
                cell.contents = shape.image.cgImage
                cell.color = color.cgColor             // 白色纹理被染成彩色

                cell.birthRate = 85                    // × 18 cell × 0.08s ≈ 120 粒子
                cell.lifetime = 4.5
                cell.lifetimeRange = 1.5

                cell.velocity = 260                    // 初速度
                cell.velocityRange = 110               // ±110，部分粒子慢
                cell.emissionLongitude = -.pi / 2      // 中心方向：向上（戏剧化"爆出"）
                cell.emissionRange = 2 * .pi           // 但 range 整 360° → 各方向都有

                cell.spin = 4
                cell.spinRange = 8
                cell.scale = 0.28                      // 粒子尺寸缩半（原 0.55）
                cell.scaleRange = 0.10
                cell.scaleSpeed = -0.04
                cell.alphaSpeed = -0.18

                cell.yAcceleration = 0                 // 起始无重力，由动画拉起
                cells.append(cell)
            }
        }
        return cells
    }

    // MARK: - 粒子形状纹理（纯白，颜色由 cell.color 染色）

    /// 从 SwiftConfettiView pod 的 bundle 找到 confetti.mp3，懒加载 AVAudioPlayer
    /// 并按需调用 play()。使用 .ambient 类别 → 不打断/抢占其他音频，遵循静音开关。
    private func playBurstSound() {
        if burstAudioPlayer == nil {
            guard let url = Self.locateBurstSoundURL() else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                burstAudioPlayer = try AVAudioPlayer(contentsOf: url)
                burstAudioPlayer?.prepareToPlay()
            } catch {
                burstAudioPlayer = nil
                return
            }
        }
        burstAudioPlayer?.currentTime = 0
        burstAudioPlayer?.play()
    }

    /// CocoaPods 既可能把资源直接打进 framework bundle（默认），也可能用
    /// resource_bundles 单独一个 .bundle —— 两条路径都试。
    private static func locateBurstSoundURL() -> URL? {
        let frameworkBundle = Bundle(for: SwiftConfettiView.self)
        if let url = frameworkBundle.url(forResource: "confetti", withExtension: "mp3") {
            return url
        }
        if let nestedBundleURL = frameworkBundle.url(forResource: "SwiftConfettiView", withExtension: "bundle"),
           let nested = Bundle(url: nestedBundleURL),
           let url = nested.url(forResource: "confetti", withExtension: "mp3") {
            return url
        }
        return nil
    }

    /// 全场欢呼短音（cheer_short.m4a，2.10s）。资产位于
    /// WuKongBase/Assets/Other/，通过 podspec 的 `WuKongBase_resources`
    /// resource_bundle 打包。CC0 公有领域，无版权限制。
    private func playCheerSound() {
        if cheerAudioPlayer == nil {
            guard let url = Self.locateCheerSoundURL() else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                cheerAudioPlayer = try AVAudioPlayer(contentsOf: url)
                cheerAudioPlayer?.volume = 0.85   // 略低于 100%，避免压过爆裂声
                cheerAudioPlayer?.prepareToPlay()
            } catch {
                cheerAudioPlayer = nil
                return
            }
        }
        cheerAudioPlayer?.currentTime = 0
        cheerAudioPlayer?.play()
    }

    /// 在 WuKongBase 资源 bundle 里找 cheer_short.m4a。
    /// CocoaPods 用 resource_bundles 打包时是一个独立 .bundle 子文件夹，
    /// 并且保留了源目录结构（文件在 `Other/` 子目录下，不是 bundle 根）。
    private static func locateCheerSoundURL() -> URL? {
        let mainBundle = Bundle(for: WKConfettiView.self)
        // 1) bundle 根（防御性，万一打包方式变了）
        if let url = mainBundle.url(forResource: "cheer_short", withExtension: "m4a") {
            return url
        }
        if let url = mainBundle.url(forResource: "cheer_short", withExtension: "m4a", subdirectory: "Other") {
            return url
        }
        // 2) WuKongBase_resources.bundle 子 bundle（实际打包路径）
        if let resBundleURL = mainBundle.url(forResource: "WuKongBase_resources", withExtension: "bundle"),
           let resBundle = Bundle(url: resBundleURL) {
            if let url = resBundle.url(forResource: "cheer_short", withExtension: "m4a", subdirectory: "Other") {
                return url
            }
            if let url = resBundle.url(forResource: "cheer_short", withExtension: "m4a") {
                return url
            }
        }
        return nil
    }

    // MARK: - 粒子形状纹理 (cont.)

    private static let rectParticleImage: UIImage = {
        let size = CGSize(width: 8, height: 14)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.white.setFill()
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: 1.5
            ).fill()
        }
    }()

    private static let starParticleImage: UIImage = {
        let size = CGSize(width: 14, height: 14)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let cx: CGFloat = 7, cy: CGFloat = 7
            let outer: CGFloat = 6.5, inner: CGFloat = 2.7
            let path = UIBezierPath()
            for i in 0..<10 {
                let radius = i % 2 == 0 ? outer : inner
                let angle = CGFloat(i) * .pi / 5 - .pi / 2
                let pt = CGPoint(x: cx + radius * cos(angle),
                                 y: cy + radius * sin(angle))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.close()
            UIColor.white.setFill()
            path.fill()
        }
    }()

    private static let triangleParticleImage: UIImage = {
        let size = CGSize(width: 12, height: 11)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 6, y: 1))
            path.addLine(to: CGPoint(x: 11, y: 10))
            path.addLine(to: CGPoint(x: 1, y: 10))
            path.close()
            UIColor.white.setFill()
            path.fill()
        }
    }()

    /// 爆开瞬间：闪光 + 球身整体放大消失（不再分解成粒子碎片，让 CAEmitter
    /// 独立处理飞散；视觉上球"啵"一下没了）+ 一圈冲击环扩散
    private func performBurst(ball: UIView, at center: CGPoint) {
        // 1) 闪光：0.05s 极速变白 → 0.20s 扩散淡出
        addBurstFlash(at: center)

        // 2) 球身整体：0.12s 放大到 1.4 + alpha 归零
        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            ball.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
            ball.alpha = 0
        } completion: { _ in
            ball.removeFromSuperview()
        }

        // 3) 冲击环：CAShapeLayer 空心圆，0.4s 内 scale 0.3 → 3.5 + opacity 0.9 → 0
        let ringInitialSize: CGFloat = 60
        let ring = CAShapeLayer()
        ring.frame = CGRect(
            x: center.x - ringInitialSize / 2,
            y: center.y - ringInitialSize / 2,
            width: ringInitialSize,
            height: ringInitialSize
        )
        ring.path = UIBezierPath(
            ovalIn: CGRect(x: 0, y: 0, width: ringInitialSize, height: ringInitialSize)
        ).cgPath
        ring.strokeColor = UIColor(white: 1.0, alpha: 0.85).cgColor
        ring.fillColor = UIColor.clear.cgColor
        ring.lineWidth = 2
        layer.addSublayer(ring)

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.3
        scaleAnim.toValue = 3.5
        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0.9
        opacityAnim.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scaleAnim, opacityAnim]
        group.duration = 0.40
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        ring.add(group, forKey: "burstRing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak ring] in
            ring?.removeFromSuperlayer()
        }
    }

    /// 爆开闪光：0.05s 极速亮白 → 0.20s 扩散淡出
    private func addBurstFlash(at center: CGPoint) {
        let flashSize: CGFloat = 90
        let flash = UIView(frame: CGRect(x: 0, y: 0,
                                         width: flashSize, height: flashSize))
        flash.center = center
        flash.layer.cornerRadius = flashSize / 2
        flash.backgroundColor = UIColor(white: 1.0, alpha: 0.85)
        flash.transform = CGAffineTransform(scaleX: 0.30, y: 0.30)
        flash.alpha = 0
        addSubview(flash)

        UIView.animate(
            withDuration: 0.05,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            flash.alpha = 1.0
            flash.transform = .identity
        } completion: { _ in
            UIView.animate(
                withDuration: 0.20,
                delay: 0,
                options: [.curveEaseIn]
            ) {
                flash.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
                flash.alpha = 0
            } completion: { _ in
                flash.removeFromSuperview()
            }
        }
    }

    /// 自绘"半透明红色彩纸球"：
    ///   - 容器尺寸 = 球径 + 22pt 顶部空间，蝴蝶结 / 丝带全部放在球**外面**
    ///     （在容器顶部 22pt 区域内），不会被 shell 的圆形 mask 裁掉
    ///   - 球壳：半透明红 (alpha 0.60) + 圆形裁剪 + 细高光边
    ///   - 内嵌 120 片彩纸（rect / star / triangle × 6 色，紧密分布）
    ///   - 底部弧形暗影 + 顶部 radial gradient 高光 → 立体光泽质感
    ///   - 顶部蝴蝶结（2 翅 + 中心结）+ 2 根金色丝带从结上垂下，覆盖在球面前
    ///   - 容器 anchorPoint 设到 shell 中心 → 所有 transform 围绕球心，
    ///     不围绕容器几何中心（避免被偏上的 bow 拉偏）
    private func makeConfettiBall(diameter: CGFloat, center: CGPoint) -> UIView {
        let extraTop: CGFloat = 28
        let containerW = diameter
        let containerH = diameter + extraTop

        let container = UIView(frame: CGRect(x: 0, y: 0,
                                             width: containerW,
                                             height: containerH))
        container.backgroundColor = .clear

        // ========== 球壳（容器下方 diameter × diameter 区域）==========
        let shell = UIView(frame: CGRect(x: 0, y: extraTop,
                                         width: diameter, height: diameter))
        shell.layer.cornerRadius = diameter / 2
        shell.layer.masksToBounds = true
        shell.backgroundColor = UIColor(red: 0.93, green: 0.25, blue: 0.30, alpha: 0.60)
        shell.layer.borderColor = UIColor(white: 1.0, alpha: 0.55).cgColor
        shell.layer.borderWidth = 1.0

        // 底部弧形暗影（球底立体感）
        let bottomShadow = UIView(frame: CGRect(
            x: 0,
            y: diameter * 0.55,
            width: diameter,
            height: diameter * 0.45
        ))
        bottomShadow.backgroundColor = UIColor(red: 0.40, green: 0.05, blue: 0.08, alpha: 0.35)
        shell.addSubview(bottomShadow)

        // 内嵌 120 片彩纸
        let palette = Self.ballPalette
        let shapes: [(image: UIImage, baseSize: CGFloat)] = [
            (Self.rectParticleImage,     7),
            (Self.starParticleImage,     8),
            (Self.triangleParticleImage, 7),
        ]
        let innerRadius = diameter / 2 - 3
        for i in 0..<120 {
            let shape = shapes[i % shapes.count]
            let color = palette[i % palette.count]
            let r = innerRadius * sqrt(CGFloat.random(in: 0...1))
            let theta = CGFloat.random(in: 0...(2 * .pi))
            let cx = diameter / 2 + r * cos(theta)
            let cy = diameter / 2 + r * sin(theta)
            let baseSize = shape.baseSize + CGFloat.random(in: -1...1.5)
            let aspect = shape.image.size.width / shape.image.size.height
            let w = baseSize * aspect
            let h = baseSize
            let iv = UIImageView(image: shape.image.withRenderingMode(.alwaysTemplate))
            iv.tintColor = color
            iv.frame = CGRect(x: 0, y: 0, width: w, height: h)
            iv.center = CGPoint(x: cx, y: cy)
            iv.transform = CGAffineTransform(rotationAngle: CGFloat.random(in: 0...(2 * .pi)))
            shell.addSubview(iv)
        }

        // 顶部 radial gradient 高光（光泽 / 质感）
        let highlight = CAGradientLayer()
        highlight.type = .radial
        let hSize = diameter * 0.50
        highlight.frame = CGRect(
            x: diameter * 0.10, y: diameter * 0.10,
            width: hSize, height: hSize * 0.85
        )
        highlight.colors = [
            UIColor(white: 1.0, alpha: 0.50).cgColor,
            UIColor(white: 1.0, alpha: 0.18).cgColor,
            UIColor(white: 1.0, alpha: 0.0).cgColor,
        ]
        highlight.locations = [0, 0.5, 1.0]
        highlight.startPoint = CGPoint(x: 0.5, y: 0.5)
        highlight.endPoint = CGPoint(x: 1.0, y: 1.0)
        shell.layer.addSublayer(highlight)

        container.addSubview(shell)

        // ========== 蝴蝶结 🎀 + 飘带 ==========
        // 设计：
        //  - 每个环 = UIView wrapper 内含 3 层 CAShapeLayer：
        //      ring (红椭圆 + 投影做 3D)，hole (深红椭圆做环洞)，
        //      highlight (顶部白色小椭圆模拟光从上方打)
        //  - wrapper 旋转 ±14° 给"歪头扎结"的自然姿态
        //  - 中心结 + 飘带也都自带投影，整体浮在球上有立体感
        //  - bowCenterY = 28 = shell.frame.minY → 环中心正好落在球顶边缘
        let bowCenterX = containerW / 2
        let bowCenterY: CGFloat = extraTop      // = 28，球顶边缘

        let bowRed     = UIColor(red: 0.95, green: 0.20, blue: 0.28, alpha: 1.0)
        let bowDark    = UIColor(red: 0.55, green: 0.05, blue: 0.10, alpha: 1.0)
        let bowShine   = UIColor(white: 1.0, alpha: 0.55)
        let ribbonGold = UIColor(red: 1.00, green: 0.84, blue: 0.20, alpha: 0.95)

        let loopW: CGFloat = 18
        let loopH: CGFloat = 14
        let loopOverlap: CGFloat = 2
        let loopTiltDeg: CGFloat = 14

        // 闭包工厂：生成一个带 3D 效果的椭圆环 wrapper
        let makeLoop: (_ mirrored: Bool) -> UIView = { mirrored in
            let wrapper = UIView(frame: CGRect(x: 0, y: 0, width: loopW, height: loopH))
            wrapper.backgroundColor = .clear

            // 1) ring：红椭圆 + 投影
            let ring = CAShapeLayer()
            let ringPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0,
                                                       width: loopW, height: loopH)).cgPath
            ring.path = ringPath
            ring.fillColor = bowRed.cgColor
            ring.shadowColor = UIColor.black.cgColor
            ring.shadowOpacity = 0.32
            ring.shadowRadius = 2.5
            ring.shadowOffset = CGSize(width: 0, height: 2)
            ring.shadowPath = ringPath
            wrapper.layer.addSublayer(ring)

            // 2) hole：深红椭圆做环洞
            let hole = CAShapeLayer()
            hole.path = UIBezierPath(ovalIn: CGRect(x: 3, y: 3,
                                                    width: loopW - 6, height: loopH - 6)).cgPath
            hole.fillColor = bowDark.cgColor
            hole.opacity = 0.55
            wrapper.layer.addSublayer(hole)

            // 3) highlight：顶部白色小椭圆，模拟从上方打光
            let hlW = loopW * 0.55
            let hlH = loopH * 0.25
            let highlight = CAShapeLayer()
            highlight.path = UIBezierPath(ovalIn: CGRect(
                x: (loopW - hlW) / 2,
                y: 1.5,
                width: hlW,
                height: hlH
            )).cgPath
            highlight.fillColor = bowShine.cgColor
            wrapper.layer.addSublayer(highlight)

            // 4) 倾斜
            let angle = (mirrored ? loopTiltDeg : -loopTiltDeg) * .pi / 180
            wrapper.transform = CGAffineTransform(rotationAngle: angle)
            return wrapper
        }

        // 左环
        let leftLoop = makeLoop(false)
        leftLoop.center = CGPoint(x: bowCenterX - loopW / 2 + loopOverlap, y: bowCenterY)
        container.addSubview(leftLoop)

        // 右环（镜像）
        let rightLoop = makeLoop(true)
        rightLoop.center = CGPoint(x: bowCenterX + loopW / 2 - loopOverlap, y: bowCenterY)
        container.addSubview(rightLoop)

        // 中心结：深红圆角矩形 + 投影 + 左侧细高光（侧光 3D 暗示）
        let knotW: CGFloat = 7
        let knotH: CGFloat = 17
        let knotWrapper = UIView(frame: CGRect(x: 0, y: 0, width: knotW, height: knotH))
        knotWrapper.backgroundColor = .clear

        let knotShape = CAShapeLayer()
        let knotPath = UIBezierPath(
            roundedRect: CGRect(x: 0, y: 0, width: knotW, height: knotH),
            cornerRadius: 2.5
        ).cgPath
        knotShape.path = knotPath
        knotShape.fillColor = bowDark.cgColor
        knotShape.shadowColor = UIColor.black.cgColor
        knotShape.shadowOpacity = 0.32
        knotShape.shadowRadius = 2.5
        knotShape.shadowOffset = CGSize(width: 0, height: 2)
        knotShape.shadowPath = knotPath
        knotWrapper.layer.addSublayer(knotShape)

        // 结左侧细高光条
        let knotHL = CAShapeLayer()
        knotHL.path = UIBezierPath(
            roundedRect: CGRect(x: 1.2, y: 2.5, width: 1.5, height: knotH - 5),
            cornerRadius: 0.75
        ).cgPath
        knotHL.fillColor = UIColor(white: 1.0, alpha: 0.40).cgColor
        knotWrapper.layer.addSublayer(knotHL)

        knotWrapper.center = CGPoint(x: bowCenterX, y: bowCenterY)
        container.addSubview(knotWrapper)

        // === 2 根金色飘带（CAShapeLayer，含 V 缺口 + 投影）===
        for sign: CGFloat in [-1, 1] {
            let topX = bowCenterX + sign * 1.5
            let topY = bowCenterY + knotH / 2 - 1
            let bottomX = bowCenterX + sign * 10
            let bottomY = topY + 30
            let topWidth: CGFloat = 3.5
            let bottomWidth: CGFloat = 5.5

            let dx = bottomX - topX
            let dy = bottomY - topY
            let len = sqrt(dx * dx + dy * dy)
            let nx = -dy / len
            let ny = dx / len

            let notchDepth: CGFloat = 5
            let notchX = bottomX - (dx / len) * notchDepth
            let notchY = bottomY - (dy / len) * notchDepth

            let path = UIBezierPath()
            path.move(to: CGPoint(x: topX - nx * topWidth / 2,
                                   y: topY - ny * topWidth / 2))
            path.addLine(to: CGPoint(x: bottomX - nx * bottomWidth / 2,
                                      y: bottomY - ny * bottomWidth / 2))
            path.addLine(to: CGPoint(x: notchX, y: notchY))
            path.addLine(to: CGPoint(x: bottomX + nx * bottomWidth / 2,
                                      y: bottomY + ny * bottomWidth / 2))
            path.addLine(to: CGPoint(x: topX + nx * topWidth / 2,
                                      y: topY + ny * topWidth / 2))
            path.close()

            let tail = CAShapeLayer()
            tail.path = path.cgPath
            tail.fillColor = ribbonGold.cgColor
            tail.shadowColor = UIColor.black.cgColor
            tail.shadowOpacity = 0.28
            tail.shadowRadius = 2
            tail.shadowOffset = CGSize(width: 0, height: 1.5)
            tail.shadowPath = path.cgPath
            // 飘带在结之下（结遮住飘带顶端拼接点）
            container.layer.insertSublayer(tail, below: knotWrapper.layer)
        }

        // ========== anchor point 落到球心 → transform 围绕球心 ==========
        let anchorY = (extraTop + diameter / 2) / containerH
        container.layer.anchorPoint = CGPoint(x: 0.5, y: anchorY)
        container.center = center

        return container
    }

    private static let ballPalette: [UIColor] = [
        UIColor(red: 1.00, green: 0.78, blue: 0.36, alpha: 1.0), // 黄
        UIColor(red: 0.48, green: 0.78, blue: 0.64, alpha: 1.0), // 绿
        UIColor(red: 0.30, green: 0.76, blue: 0.85, alpha: 1.0), // 青
        UIColor(red: 0.58, green: 0.39, blue: 0.75, alpha: 1.0), // 紫
        UIColor(red: 0.95, green: 0.85, blue: 0.20, alpha: 1.0), // 金
        UIColor(red: 0.97, green: 0.27, blue: 0.36, alpha: 1.0), // 粉红
    ]
}


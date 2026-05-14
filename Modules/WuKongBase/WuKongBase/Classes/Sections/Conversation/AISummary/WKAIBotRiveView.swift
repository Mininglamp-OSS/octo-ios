//
//  WKAIBotRiveView.swift
//  WuKongBase
//
//  AI 一键总结浮动按钮的视觉层。
//  封装 cat-robot.riv（State Machine 1）+ Rive Runtime，向 OC 暴露简化 API。
//
//  Rive 状态/输入对照（来自 .riv 实测）：
//    Inputs:    Walk(Trigger), StopWalk(Trigger), text(Bool)
//    Listeners: HitWalk / HitWalkStop / HitPointerMove / hitTextGreetings
//
//  v1 范围：只用 Walk / StopWalk Trigger 切走/停；停时由 Rive 自身的 idle
//  状态自然观望。设备倾斜/反应式一瞥等"活着"信号留到 v2，要做的话走
//  riveModel.stateMachine.touchMovedAtLocation 喂指针事件给 HitPointerMove。
//

import UIKit
import QuartzCore
import RiveRuntime

@objc public final class WKAIBotRiveView: UIView {

    // MARK: - Public API (OC 可见)

    /// 触发 Walk 状态（Trigger Input）
    @objc public func walk() {
        viewModel.triggerInput("Walk")
    }

    /// 触发 StopWalk 状态（Trigger Input）
    @objc public func stopWalk() {
        viewModel.triggerInput("StopWalk")
    }

    /// 控制猫顶上文字气泡（Bool Input "text"）
    @objc public func setBubble(_ on: Bool) {
        viewModel.setInput("text", value: on)
    }

    // MARK: - Init

    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        setupRive()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupRive()
    }

    // MARK: - Internal

    private lazy var viewModel: RiveViewModel = {
        return RiveViewModel(
            fileName: "cat-robot",
            in: WKAIBotRiveView.riveBundle,
            stateMachineName: "State Machine 1",
            fit: .contain,
            alignment: .center,
            autoPlay: true,
            artboardName: "RobotCat_01.png"   // 裸猫；默认的 RobotCat_02 自带蓝色按钮光晕装饰组
        )
    }()

    private lazy var riveView: RiveView = viewModel.createRiveView()

    private func setupRive() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false  // 容器不拦截事件，点击交给外层 button
        riveView.translatesAutoresizingMaskIntoConstraints = false
        riveView.isUserInteractionEnabled = false
        riveView.backgroundColor = .clear
        riveView.isOpaque = false
        // CAMetalLayer 底层也要明确允许透明，否则会用 opaque=true 的默认 black/blue 清屏
        if let metal = riveView.layer as? CAMetalLayer {
            metal.isOpaque = false
        }
        // 帧率压到 30 —— cat 的走路/idle 在 30fps 完全够看，把另一半时间还给 UIScrollView
        riveView.setPreferredFramesPerSecond(preferredFramesPerSecond: 30)
        // 不按 @3x 渲染，按 @2x —— 120pt 的小尺寸不需要 @3x 像素密度
        riveView.contentScaleFactor = 2.0

        addSubview(riveView)
        NSLayoutConstraint.activate([
            riveView.leadingAnchor.constraint(equalTo: leadingAnchor),
            riveView.trailingAnchor.constraint(equalTo: trailingAnchor),
            riveView.topAnchor.constraint(equalTo: topAnchor),
            riveView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // 调试：打印 .riv 里所有 artboard 名，便于挑一个无背景的
        NSLog("[WKAIBot] artboards in cat-robot.riv: %@", viewModel.artboardNames())
    }

    // MARK: - Bundle 解析

    /// CocoaPods resource_bundles 会生成 WuKongBase_aisummary.bundle 嵌在 framework 内。
    /// 解析失败时回落到 framework 主 bundle，再回落到 main，便于在 Demo / 测试环境也能跑。
    private static let riveBundle: Bundle = {
        let framework = Bundle(for: WKAIBotRiveView.self)
        if let url = framework.url(forResource: "WuKongBase_aisummary", withExtension: "bundle"),
           let b = Bundle(url: url) {
            return b
        }
        return framework
    }()
}

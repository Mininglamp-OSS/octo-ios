// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMathImageRenderer.swift
//  WuKongBase
//
//  把 LaTeX 数学表达式渲染成 UIImage（含基线/上下沿度量），由
//  WKLaTeXPreprocessor.replaceMathPlaceholdersIn 装进 NSTextAttachment 注入
//  消息富文本。基于 iosMath（纯 OC + CoreText，无 WebView，无 runloop 嵌套）。
//
//  缓存按 (tex, fontSize, colorHex, isDisplay) 走 NSCache LRU，countLimit 200，
//  totalCostLimit 5MB。深色模式切换通过 colorHex 自然 invalidate。
//

import Foundation
import UIKit
import iosMath

@objc public class WKMathImageResult: NSObject {
    @objc public let image: UIImage
    /// 数学图像基线以上高度（同一行文字基线对齐用）
    @objc public let ascent: CGFloat
    /// 数学图像基线以下高度
    @objc public let descent: CGFloat
    /// 图像宽度
    @objc public let width: CGFloat

    @objc public init(image: UIImage, ascent: CGFloat, descent: CGFloat, width: CGFloat) {
        self.image = image
        self.ascent = ascent
        self.descent = descent
        self.width = width
    }
}

@objc public class WKMathImageRenderer: NSObject {

    private static let cache: NSCache<NSString, WKMathImageResult> = {
        let c = NSCache<NSString, WKMathImageResult>()
        c.countLimit = 200
        c.totalCostLimit = 5 * 1024 * 1024  // 5 MB pixels (approx)
        return c
    }()

    /// 渲染 LaTeX 数学到 UIImage。失败返回 nil（调用方走 monospace 回退）。
    ///
    /// 线程安全：MTMathUILabel 是 UIView 子类，离主线程创建会触发 Main Thread Checker。
    /// 但 WKMessageListView 的预测高度路径 (precacheHeightForMessage:) 把
    /// parseAndCacheTextMessage: 派到 global queue 上跑，链路会带到这里。
    /// 所以这里非主线程时先查 NSCache（线程安全）；缓存命中就直接返回避免 hop；
    /// 缓存未命中再 dispatch_sync 到主线程做真渲染。
    /// 调用方 parseAndCacheTextMessage: 在 bg 是非阻塞的（dispatch_async），main
    /// 不会等 bg 完成 → dispatch_sync 不会死锁。
    @objc public static func render(tex: String,
                                    fontSize: CGFloat,
                                    textColor: UIColor,
                                    isDisplay: Bool) -> WKMathImageResult? {
        guard !tex.isEmpty else { return nil }

        let key = cacheKey(tex: tex, fontSize: fontSize, textColor: textColor, isDisplay: isDisplay)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        if Thread.isMainThread {
            return _renderUncached(tex: tex, key: key, fontSize: fontSize, textColor: textColor, isDisplay: isDisplay)
        }
        var result: WKMathImageResult?
        DispatchQueue.main.sync {
            // 主线程上有可能其他 caller 已经 fill 了，再 check 一次。
            if let cached = cache.object(forKey: key) {
                result = cached
            } else {
                result = _renderUncached(tex: tex, key: key, fontSize: fontSize, textColor: textColor, isDisplay: isDisplay)
            }
        }
        return result
    }

    /// TeX 源最大长度，超过直接拒绝渲染。远端消息可能塞超长公式刷栈/OOM，
    /// iosMath 解析超长公式本身也慢得离谱。回退到 monospace 至少可读。
    private static let maxTexLength: Int = 4096
    /// 渲染图像最大像素面积，超过拒绝 UIGraphicsImageRenderer 分配。
    /// 防御点：MTMathUILabel 解析成功但矩阵/巨型公式输出极宽极高，瞬时
    /// 分配几十 MB 位图导致 OOM。2M 像素 ≈ 8MB RGBA，温和上限。
    private static let maxImageArea: CGFloat = 2_000_000

    private static func _renderUncached(tex: String,
                                         key: NSString,
                                         fontSize: CGFloat,
                                         textColor: UIColor,
                                         isDisplay: Bool) -> WKMathImageResult? {

        // 长度闸：缓存以 (tex, ...) 为 key, 缓存 LRU 只能在分配之后才驱逐,
        // 所以源长度必须在 MTMathUILabel 解析前先拦。
        if tex.count > maxTexLength {
            #if DEBUG
            NSLog("[WKMathImageRenderer] rejecting tex (len=%d > %d) tex_prefix=%@",
                  tex.count, maxTexLength, String(tex.prefix(80)))
            #endif
            return nil
        }

        // 构建 MTMathUILabel；解析失败时 .error 非空。
        let label = MTMathUILabel()
        label.latex = tex
        label.fontSize = fontSize
        label.textColor = textColor
        label.labelMode = isDisplay ? .display : .text
        label.contentInsets = .zero
        label.textAlignment = .left
        label.backgroundColor = .clear

        // 关键：MTMathUILabel.displayList 是在 layoutSubviews 里 lazy 构建的。光设
        // latex 拿不到 displayList。必须先 sizeThatFits 量出尺寸 → 写入 frame →
        // 强制 layoutIfNeeded，这样 displayList 才被填充，否则后面所有度量都拿 nil。
        let measureSize = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                    height: CGFloat.greatestFiniteMagnitude))
        guard measureSize.width > 0.5, measureSize.height > 0.5 else { return nil }
        label.bounds = CGRect(origin: .zero, size: measureSize)
        label.setNeedsLayout()
        label.layoutIfNeeded()

        guard label.error == nil, let display = label.displayList else {
            #if DEBUG
            NSLog("[WKMathImageRenderer] iosMath failed for tex=%@ err=%@", tex, String(describing: label.error))
            #endif
            return nil
        }

        // 严格按 displayList 的 ascent/descent/width 画图，确保基线信息精确。
        let ascent = display.ascent
        let descent = display.descent
        let width = display.width
        let height = ascent + descent
        guard width > 0.5, height > 0.5 else { return nil }

        // MTMathUILabel.layoutSubviews 会把 display.position 设为 (0, descent) 用于
        // 在 label bounds 里垂直居中。我们要的是从原点画，所以归零；否则会在下面的
        // CGContext transform 之外再叠加一次 descent 偏移，math 顶部超出 image 被裁。
        display.position = .zero

        // 给 1pt 边距吸收子像素抗锯齿，避免左右两端被裁掉。
        let pad: CGFloat = 1.0
        let imageW = ceil(width) + pad * 2
        let imageH = ceil(height) + pad * 2
        // 面积闸：在 UIGraphicsImageRenderer 分配前拦截。RGBA 4 字节, 2M 像素 ≈ 8MB,
        // 单条消息天花板, 防止矩阵/超宽公式撑爆。回退到 monospace 也至少可读。
        if imageW * imageH > maxImageArea {
            #if DEBUG
            NSLog("[WKMathImageRenderer] rejecting oversized image (%.0fx%.0f area=%.0f > %.0f) tex_prefix=%@",
                  imageW, imageH, imageW * imageH, maxImageArea, String(tex.prefix(80)))
            #endif
            return nil
        }
        let size = CGSize(width: imageW, height: imageH)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { rendererCtx in
            let ctx = rendererCtx.cgContext
            ctx.saveGState()
            // 让 (0, 0) 落在 baseline（图片顶部 pad + ascent 处），y 轴翻转成 iosMath
            // 期望的 "向上为正"。display.draw 此时直接画 baseline 之上的 ascent 部分
            // 和 baseline 之下的 descent 部分，刚好填满 pad ~ imageH-pad。
            ctx.translateBy(x: pad, y: pad + ascent)
            ctx.scaleBy(x: 1, y: -1)
            display.textColor = textColor
            display.draw(ctx)
            ctx.restoreGState()
        }

        let result = WKMathImageResult(image: image,
                                       ascent: ascent + pad,
                                       descent: descent + pad,
                                       width: size.width)
        let cost = Int(size.width * size.height * 4)
        cache.setObject(result, forKey: key, cost: cost)
        return result
    }

    @objc public static func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - Cache key

    private static func cacheKey(tex: String, fontSize: CGFloat, textColor: UIColor, isDisplay: Bool) -> NSString {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        textColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let colorHex = String(format: "%02X%02X%02X%02X",
                              Int(round(r * 255)),
                              Int(round(g * 255)),
                              Int(round(b * 255)),
                              Int(round(a * 255)))
        let display = isDisplay ? "D" : "T"
        // 字号取一位小数即可，避免浮点波动导致 cache miss
        let sz = Int(fontSize * 10)
        return "\(sz)|\(colorHex)|\(display)|\(tex)" as NSString
    }
}

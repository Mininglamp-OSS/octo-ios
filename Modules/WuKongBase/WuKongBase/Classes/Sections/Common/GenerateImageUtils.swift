//
//  GenerateImageUtils.swift
//  WuKongBase
//
//  Native CoreGraphics implementation. Originally wrapped TelegramUtils helpers;
//  rewritten in P5 to remove the GPL v2 dependency. Public ObjC interface unchanged.
//

import Foundation
import UIKit

@objc public class GenerateImageUtils: NSObject {

    // MARK: - Public ObjC API (unchanged)

    @objc public static func generateTintedImg(image: UIImage?, color: UIColor, backgroundColor: UIColor? = nil) -> UIImage? {
        guard let image = image, let cgImage = image.cgImage else { return nil }
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, backgroundColor != nil, image.scale)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        let rect = CGRect(origin: .zero, size: size)
        if let bg = backgroundColor {
            ctx.setFillColor(bg.cgColor)
            ctx.fill(rect)
        }
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.clip(to: rect, mask: cgImage)
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    @objc public static func generateImg(_ size: CGSize, opaque: Bool = false, rotatedContext: (CGSize, CGContext) -> Void) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        UIGraphicsBeginImageContextWithOptions(size, opaque, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        // TelegramUtils-compatible behavior: y-flip so caller draws as if origin is bottom-left
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        rotatedContext(size, ctx)
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    @objc public static func generateImg(_ size: CGSize, contextGenerator: (CGSize, CGContext) -> Void, opaque: Bool = false) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        UIGraphicsBeginImageContextWithOptions(size, opaque, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        contextGenerator(size, ctx)
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    @objc public static func drawWallpaperGradientImage(_ colors: [UIColor], context: CGContext, size: CGSize, rotation: Int32) {
        self.drawWallpaperGradientImage(colors, rotation: rotation, context: context, size: size)
    }

    @objc public static func drawWallpaperGradientImage(_ colors: [UIColor], context: CGContext, size: CGSize) {
        self.drawWallpaperGradientImage(colors, rotation: nil, context: context, size: size)
    }

    public static func drawWallpaperGradientImage(_ colors: [UIColor], rotation: Int32? = nil, context: CGContext, size: CGSize) {
        guard !colors.isEmpty else { return }
        guard colors.count > 1 else {
            context.setFillColor(colors[0].cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            return
        }
        let drawingRect = CGRect(origin: .zero, size: size)
        let gradientColors = colors.map { $0.withAlphaComponent(1.0).cgColor } as CFArray
        let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
        var locations: [CGFloat] = (0 ..< colors.count).map { delta * CGFloat($0) }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations) else { return }

        if let rotation = rotation {
            context.saveGState()
            context.translateBy(x: drawingRect.width / 2.0, y: drawingRect.height / 2.0)
            context.rotate(by: CGFloat(rotation) * .pi / 180.0)
            context.translateBy(x: -drawingRect.width / 2.0, y: -drawingRect.height / 2.0)
        }
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0.0, y: 0.0),
                                   end: CGPoint(x: 0.0, y: drawingRect.height),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        if rotation != nil {
            context.restoreGState()
        }
    }
}

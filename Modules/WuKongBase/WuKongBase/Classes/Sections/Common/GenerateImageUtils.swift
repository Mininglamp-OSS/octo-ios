//
//  GenerateImageUtils.swift
//  WuKongBase
//
//  Created by tt on 2022/6/21.
//

import Foundation

@objc public class GenerateImageUtils: NSObject {
    
    @objc public static func generateTintedImg(image: UIImage?, color: UIColor, backgroundColor: UIColor? = nil) -> UIImage? {
        
        return generateTintedImage(image: image, color: color,backgroundColor:backgroundColor)
    }
    
    @objc public static func generateImg(_ size: CGSize, opaque: Bool = false, rotatedContext: (CGSize, CGContext) -> Void) -> UIImage? {
        return generateImage(size, rotatedContext: rotatedContext)
    }
    
    @objc public static func generateImg(_ size: CGSize, contextGenerator: (CGSize, CGContext) -> Void, opaque: Bool = false) -> UIImage? {
        
        return generateImage(size, contextGenerator: contextGenerator, opaque: opaque, scale: nil)
    }
    
    
    @objc public static func drawWallpaperGradientImage(_ colors: [UIColor], context: CGContext, size: CGSize,rotation:Int32) {
        self.drawWallpaperGradientImage(colors,rotation:rotation,context:context,size:size);
    }
    
   
    public static func drawWallpaperGradientImage(_ colors: [UIColor], rotation: Int32? = nil, context: CGContext, size: CGSize) {
        guard !colors.isEmpty else {
            return
        }
        guard colors.count > 1 else {
            context.setFillColor(colors[0].cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            return
        }

        let drawingRect = CGRect(origin: CGPoint(), size: size)

        let c = context

        if colors.count >= 3 {
            let image = GradientBackgroundNode.generatePreview(size: CGSize(width: 60.0, height: 60.0), colors: colors)
            c.translateBy(x: drawingRect.midX, y: drawingRect.midY)
            c.scaleBy(x: 1.0, y: -1.0)
            c.translateBy(x: -drawingRect.midX, y: -drawingRect.midY)
            c.draw(image.cgImage!, in: drawingRect)
            c.translateBy(x: drawingRect.midX, y: drawingRect.midY)
            c.scaleBy(x: 1.0, y: -1.0)
            c.translateBy(x: -drawingRect.midX, y: -drawingRect.midY)
        } else {
            let gradientColors = colors.map { $0.withAlphaComponent(1.0).cgColor } as CFArray
            let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)

            var locations: [CGFloat] = []
            for i in 0 ..< colors.count {
                locations.append(delta * CGFloat(i))
            }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

            if let rotation = rotation {
                c.saveGState()
                c.translateBy(x: drawingRect.width / 2.0, y: drawingRect.height / 2.0)
                c.rotate(by: CGFloat(rotation) * CGFloat.pi / 180.0)
                c.translateBy(x: -drawingRect.width / 2.0, y: -drawingRect.height / 2.0)
            }

            c.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: drawingRect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

            if rotation != nil {
                c.restoreGState()
            }
        }
    }
    @objc public static func drawWallpaperGradientImage(_ colors: [UIColor], context: CGContext, size: CGSize) {
        self.drawWallpaperGradientImage(colors, rotation: nil, context: context, size: size)
    }
}

//
//  WKAnimatedStickerNode.swift
//  WuKongBase
//
//  Created by tt on 2022/6/23.
//

import Foundation
import UIKit

@objc public class WKAnimatedStickerNode:NSObject {
    let animatedStickerNode: AnimatedStickerNode
    @objc public var started: () -> Void = {}
    @objc override public  init() {
        self.animatedStickerNode = AnimatedStickerNode(useMetalCache: false)
       
    }
    
    @objc public func setup() {
        self.animatedStickerNode.started = { [weak self] in
            self?.started()
        }
    }
    
    @objc public func updateLayout(size: CGSize) {
        animatedStickerNode.updateLayout(size: size)
    }
    
    @objc public func attach(view:UIView) {
        view.addSubnode(self.animatedStickerNode)
    }
    @objc public func setup(url:String,size:CGSize) {
        animatedStickerNode.setup(source: WKAnimatedStickerResourceSource(downloadURL: url), width: Int(size.width), height: Int(size.height),playbackMode: .loop, mode: .direct(cachePathPrefix: "sticker_"))
    }
    @objc public func play() {
        self.animatedStickerNode.play()
    }
    @objc public func stop() {
        self.animatedStickerNode.stop()
    }
}

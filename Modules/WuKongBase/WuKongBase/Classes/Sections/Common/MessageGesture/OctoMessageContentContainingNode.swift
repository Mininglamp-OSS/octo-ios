// Copyright 2024 MININGLAMP. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
// OctoMessageContentContainingNode
// --------------------------------
// 气泡内容承载节点。Octo 独立实现，替代旧
// TelegramUtils/Display/Source/ContextContentSourceNode.swift 中的
// ContextExtractedContentContainingNode（GPL v2）。
//
// cell 用法：
//   self.mainContextSourceNode = [[OctoMessageContentContainingNode alloc] init];
//   [mainContextSourceNode.contentNode.view addSubview:self.bubbleBackgroundView];
//   self.mainContextSourceNode.contentRect = backgroundFrame;
//   [self.mainContextSourceNode layoutUpdatedForOCWithSize:size];
//
// 设计：只是一个嵌套两层 ASDisplayNode 的容器，对外暴露 contentNode 给 cell
// 加 subview / contentRect 用于记录气泡矩形 / layoutUpdatedForOCWithSize: 兼容
// 旧 OC 互调用签名。其它 isExtractedToContextPreview 等字段保留 API 表面
// 但未做内容菜单的 preview 抽取逻辑（菜单已由 WKConversationContextImpl 的
// 内联实现替代，见该文件 :581 注释）。

import Foundation
import UIKit
import AsyncDisplayKit

@objc public final class OctoMessageContentNode: ASDisplayNode {
    @objc public var customHitTest: ((CGPoint) -> UIView?)?

    public override init() {
        super.init()
        self.isUserInteractionEnabled = true
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let custom = customHitTest, let v = custom(point) {
            return v
        }
        return super.hitTest(point, with: event)
    }
}

@objc public final class OctoMessageContentContainingNode: ASDisplayNode {

    @objc public let contentNode: OctoMessageContentNode
    @objc public var contentRect: CGRect = .zero

    // 保留 API 表面（菜单展开/收起 hook，cell 暂未消费）
    @objc public var isExtractedToContextPreview: Bool = false
    public var willUpdateIsExtractedToContextPreview: ((Bool) -> Void)?
    public var isExtractedToContextPreviewUpdated: ((Bool) -> Void)?
    public var requestDismiss: (() -> Void)?
    public var layoutUpdated: ((CGSize) -> Void)?

    public override init() {
        self.contentNode = OctoMessageContentNode()
        super.init()
        self.isUserInteractionEnabled = true
        self.addSubnode(self.contentNode)
    }

    public override func didLoad() {
        super.didLoad()
        self.contentNode.frame = self.bounds
    }

    public override func layout() {
        super.layout()
        self.contentNode.frame = self.bounds
    }

    @objc public func layoutUpdatedForOCWithSize(_ size: CGSize) {
        self.contentNode.frame = CGRect(origin: .zero, size: size)
        self.layoutUpdated?(size)
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
}

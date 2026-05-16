//
//  WKBubbleInteractionHelper.swift
//  WuKongBase
//
//  用于「表情特效 + 气泡物理互动」的工具：对 UITableView 可见 cell 做快照、
//  应用 UIDynamics 后恢复。这是类微信/Telegram 炸弹/冲击波效果的底层机制。

import Foundation
import UIKit

@objc public class WKBubbleSnapshot: NSObject {
    @objc public var view: UIView = UIView()
    @objc public var originalCenter: CGPoint = .zero
    @objc public weak var originalCell: UIView?
}

@objc public class WKBubbleInteractionHelper: NSObject {

    /// 对 tableView 可见 cell 做快照，将快照加到 hostView，隐藏原始 cell。
    /// 返回的 snapshot 列表保留原始 cell 弱引用以便稍后恢复。
    @objc public static func snapshotCells(in tableView: UITableView,
                                           addingTo hostView: UIView) -> [WKBubbleSnapshot] {
        var result: [WKBubbleSnapshot] = []
        for cell in tableView.visibleCells {
            guard let snapView = cell.snapshotView(afterScreenUpdates: false) else { continue }
            let frame = tableView.convert(cell.frame, to: hostView)
            snapView.frame = frame
            hostView.addSubview(snapView)
            cell.isHidden = true

            let s = WKBubbleSnapshot()
            s.view = snapView
            s.originalCenter = CGPoint(x: frame.midX, y: frame.midY)
            s.originalCell = cell
            result.append(s)
        }
        return result
    }

    /// 恢复：取消原始 cell 隐藏，移除快照视图
    @objc public static func restore(_ snapshots: [WKBubbleSnapshot]) {
        for s in snapshots {
            s.originalCell?.isHidden = false
            s.view.removeFromSuperview()
        }
    }

    /// 在 parentView 的子视图中寻找第一个 UITableView（用于定位聊天表格）
    @objc public static func findTableView(in parent: UIView?) -> UITableView? {
        guard let parent = parent else { return nil }
        for subview in parent.subviews {
            if let table = subview as? UITableView {
                return table
            }
        }
        return nil
    }

    /// 给 cell 做一次快速缩放脉冲（被击中时的反馈）
    @objc public static func pulseCell(_ cell: UIView) {
        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1.0, 1.12, 0.95, 1.03, 1.0]
        pulse.keyTimes = [0.0, 0.2, 0.5, 0.8, 1.0]
        pulse.duration = 0.35
        cell.layer.add(pulse, forKey: "bubble-pulse")
    }
}

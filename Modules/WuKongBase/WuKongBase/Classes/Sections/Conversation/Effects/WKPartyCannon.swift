//
//  WKPartyCannon.swift
//
//  ⚠️ 已废弃：SpriteKit 物理方案不可行。
//  在同一帧内 addChild + applyImpulse / 设置 body.velocity，引擎会静默吞掉
//  初始速度，导致所有粒子挤在发射点直直下坠。SKAction.applyImpulse 也无效。
//  查看 Git 历史可见完整实现。🎉 特效已回退到单独使用 WKConfettiView。
//

import Foundation

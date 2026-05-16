// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKPartyEffect.m
//
//  🎉 / 🎊 — 使用 WKConfettiView（移植自 Telegram ConfettiEffect 的 2D 物理彩纸）。
//  SpriteKit 方案尝试过但 physicsBody 的 velocity / impulse 在新建节点同帧内
//  总被引擎吞掉，改不通，已放弃（见 git 历史的 WKPartyCannon.swift）。

#import "WKPartyEffect.h"
#import "WKMessageEffectView.h"
#import "WuKongBase.h"
#import <WuKongBase/WuKongBase-Swift.h>

@implementation WKPartyEffect

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    WKConfettiView *confetti = [[WKConfettiView alloc] initWithFrame:effectView.bounds customImage:nil];
    [effectView addSubview:confetti];

    [effectView scheduleRemovalAfterDelay:10.0];
}

@end

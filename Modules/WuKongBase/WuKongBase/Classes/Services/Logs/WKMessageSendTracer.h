//
//  Copyright 2026 MININGLAMP
//  SPDX-License-Identifier: Apache-2.0
//
//  调试用途，仅用于排查聊天详情发送消息时偶发的失败/超时。
//  上线前若无需追踪，可在 WKConversationContextImpl 中把 traceSendBegin 调用注释掉，
//  Tracer 单例本身不持有任何资源、不影响发送流程。
//

#import <Foundation/Foundation.h>
@class WKMessage;
@class WKChannel;

NS_ASSUME_NONNULL_BEGIN

/// 单条消息发送链路追踪器。
/// 通过 WKChatManagerDelegate / WKConnectionManagerDelegate 监听 SDK 回调，
/// 对已登记的 clientMsgNo 输出 begin → update(WAITSEND/UPLOADING/...) → sendack/SUCCESS|FAIL 全链路日志。
@interface WKMessageSendTracer : NSObject

+ (instancetype)shared;

/// 在调用 [WKSDK sendMessage:...] 之后立即调用，message 为 SDK 返回的对象。
/// extra 可放调用方语境（如 @"resend" / @"forward"），nil 时按 @"send" 处理。
- (void)traceSendBegin:(WKMessage *)message channel:(WKChannel *)channel extra:(nullable NSString *)extra;

@end

NS_ASSUME_NONNULL_END

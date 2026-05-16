//
//  WKTypingManager.h
//  WuKongBase
//
//  Created by tt on 2020/8/13.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN
@class WKTypingManager;
@protocol WKTypingManagerDelegate <NSObject>

@optional


/// 指定频道的typing增加
/// @param manager <#manager description#>
/// @param message 消息typing
-(void) typingAdd:(WKTypingManager*)manager message:(WKMessage*)message;


/// 指定频道的typing移除
/// @param manager <#manager description#>
/// @param message 消息typing
-(void) typingRemove:(WKTypingManager*)manager message:(WKMessage*)message newMessage:(WKMessage*)message;

-(void) typingReplace:(WKTypingManager*)manager newmessage:(WKMessage*)newmessage oldmessage:(WKMessage*)oldmessage;

@end

@interface WKTypingManager : NSObject

+ (WKTypingManager *)shared;


/// 添加typing 通过消息
/// @param message <#message description#>
-(void) addTypingByMessage:(WKMessage*)message;


/// 移除指定频道的typing
/// @param channel <#channel description#>
-(void) removeTypingByChannel:(WKChannel*)channel newMessage:(WKMessage * __nullable)message;



-(BOOL) hasTyping:(WKChannel*)channel;

/// 获取所有typing消息
-(NSArray<WKMessage*>*) getAllTypingMessages;


/// 获取指定频道的typing消息
/// @param channel <#channel description#>
-(WKMessage*) getTypingMessage:(WKChannel*) channel;

/**
 添加连接委托

 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKTypingManagerDelegate>) delegate;


/**
 移除连接委托

 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKTypingManagerDelegate>) delegate;

-(WKMessage*) convertParamToTypingMessage:(NSDictionary*)param;

@end

NS_ASSUME_NONNULL_END

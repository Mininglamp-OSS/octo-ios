//
//  WKChannelSettingManager.h
//  WuKongBase
//
//  Created by tt on 2021/8/10.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <PromiseKit/PromiseKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKChannelSettingManager : NSObject

+ (instancetype _Nonnull )shared;

// 免打扰
-(void) channel:(WKChannel*)channel mute:(BOOL) on;
-(BOOL) mute:(WKChannel*)channel;

// 置顶
-(void) channel:(WKChannel*)channel stick:(BOOL) on;
-(BOOL) stick:(WKChannel*) channel;

// 消息回执
-(void) channel:(WKChannel*)channel receipt:(BOOL) on;
-(BOOL) receipt:(WKChannel*)channel;

// 聊天密码开关
-(void) channel:(WKChannel*)channel chatPwdOn:(BOOL)on;
-(BOOL)chatPwdOn:(WKChannel*)channel;

// 截屏通知
-(void) channel:(WKChannel*)uid screenshot:(BOOL) on;
-(BOOL)screenshot:(WKChannel*)channel;

// 保存到通讯录
-(void) group:(NSString*)groupNo save:(BOOL) on;
-(BOOL) save:(WKChannel*)channel;


// 撤回提醒
-(void) channel:(WKChannel*)channel revokeRemind:(BOOL)on;
-(BOOL)revokeRemind:(WKChannel*)channel;

// 进群提醒
-(void) channel:(WKChannel*)channel joinGroupRemind:(BOOL)on;
-(BOOL) joinGroupRemind:(WKChannel*)channel;


// 备注设置
-(AnyPromise*) channel:(WKChannel*)channel remark:(NSString*)remark;

// 阅后即焚
-(void) channel:(WKChannel*)channel flame:(BOOL) on;

// 阅后即焚时间
-(void) channel:(WKChannel*)channel flameSecond:(NSInteger) flameSecond;

-(NSString*) remark:(WKChannel*)channel;
@end

NS_ASSUME_NONNULL_END

//
//  WKCMDManager.h
//  WuKongIMSDK
//
//  Created by tt on 2020/10/7.
//

#import <Foundation/Foundation.h>
#import "WKSyncConversationModel.h"
@class WKCMDManager;
NS_ASSUME_NONNULL_BEGIN

@protocol WKCMDManagerDelegate <NSObject>

@optional


/// 收到命令
/// @param manager <#manager description#>
/// @param model <#model description#>
-(void) cmdManager:(WKCMDManager*)manager onCMD:(WKCMDModel*)model;

@end

@interface WKCMDManager : NSObject

// 设置验证cmd的公钥
@property(nonatomic,copy) NSString *pubKey;


/**
 添加cmd委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKCMDManagerDelegate>) delegate;


/**
 移除cmd委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKCMDManagerDelegate>) delegate;


/// 调用接受命令委托
/// @param model <#model description#>
-(void) callOnCMDDelegate:(WKCMDModel*)model;

// 拉取cmd消息
-(void) pullCMDMessages;

@end

NS_ASSUME_NONNULL_END

//
//  WKNetworkListener.h
//  WuKongBase
//
//  Created by tt on 2020/7/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class WKNetworkListener;
@protocol WKNetworkListenerDelegate <NSObject>

@optional


/// 网络状态发送变化
/// @param listener <#listener description#>
-(void) networkListenerStatusChange:(WKNetworkListener*)listener;

@end

@interface WKNetworkListener : NSObject

@property(nonatomic) BOOL hasNetwork; // 是否有网络

+ (WKNetworkListener *)shared;


/// 开始监听
-(void) start;

-(void) addDelegate:(id<WKNetworkListenerDelegate>)delegate;

- (void)removeDelegate:(id<WKNetworkListenerDelegate>) delegate;

@end

NS_ASSUME_NONNULL_END

//
//  WKWebViewService.h
//  WuKongBase
//
//  Created by tt on 2023/9/11.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@class WKWebViewJavascriptBridge;

@interface WKWebViewService : NSObject

@property (nonatomic, strong) WKWebViewJavascriptBridge *bridge;
@property(nonatomic,strong,nullable) WKChannel *channel;

-(void) registerHandlers;

@end

NS_ASSUME_NONNULL_END

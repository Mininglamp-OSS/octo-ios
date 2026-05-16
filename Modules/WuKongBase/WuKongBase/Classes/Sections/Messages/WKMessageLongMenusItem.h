//
//  WKMessageLongMenusItem.h
//  WuKongBase
//
//  Created by tt on 2020/1/28.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConversationContext.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageLongMenusItem : NSObject

+(instancetype) initWithTitle:(NSString*)title onTap:(void(^)(id<WKConversationContext> context)) onTap;

+(instancetype) initWithTitle:(NSString*)title icon:(UIImage*)icon onTap:(void(^)(id<WKConversationContext> context)) onTap;


//菜单项标题
@property(nonatomic,copy) NSString *title;
@property(nonatomic,strong,nullable) UIImage *icon;

// 菜单项被点击
@property(nonatomic,copy,nullable) void(^onTap)(id<WKConversationContext> context);

@end

NS_ASSUME_NONNULL_END

//
//  WKImageBrowser.h
//  WuKongBase
//
//  Created by tt on 2022/4/8.
//

#import <YBImageBrowser/YBImageBrowser.h>
#import "WKConversationContext.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKImageBrowser : YBImageBrowser

@property(nonatomic,copy) void(^onEditFinish)(UIImage*img);

@property(nonatomic,copy) void(^onDealloc)(void);

@property(nonatomic,weak) id<WKConversationContext> conversationContext;

@end

NS_ASSUME_NONNULL_END

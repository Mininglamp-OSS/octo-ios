//
//  WKSystemContent.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/4.
//

#import <Foundation/Foundation.h>
#import "WKMessageContent.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKSystemContent : WKMessageContent

@property(nonatomic,strong) NSDictionary *content;
@property(nonatomic,copy) NSString *displayContent;

@end

NS_ASSUME_NONNULL_END

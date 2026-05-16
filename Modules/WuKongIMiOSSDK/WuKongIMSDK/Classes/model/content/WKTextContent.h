//
//  WKText.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import <Foundation/Foundation.h>
#import "WKMessageContent.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKTextContent : WKMessageContent

- (instancetype)initWithContent:(NSString*)content;

@property(nonatomic,copy) NSString *content;

@property(nonatomic,copy,nullable) NSString *format; // 内容格式 默认为普通文本 html,markdown



@end

NS_ASSUME_NONNULL_END

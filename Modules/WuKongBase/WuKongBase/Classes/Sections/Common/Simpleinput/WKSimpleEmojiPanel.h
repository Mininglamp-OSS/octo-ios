//
//  WKSimpleEmojiPanel.h
//  WuKongBase
//
//  Created by tt on 2020/11/18.
//

#import <UIKit/UIKit.h>
#import "WKConstant.h"
#import "UIView+WK.h"
#import "WKEmoticonService.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKSimpleEmojiPanel : UIView

@property(nonatomic,copy) void(^onSend)(void); // 发送消息

@property(nonatomic,copy) void(^onEmoji)(WKEmotion *emoji); // emoji点击

-(void) layoutPanel:(CGFloat)height;


@end

NS_ASSUME_NONNULL_END

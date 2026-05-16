//
//  WKEmojiContentView.h
//  WuKongBase
//
//  Created by tt on 2020/1/10.
//

#import <UIKit/UIKit.h>
#import "WKEmoticonService.h"
#import "WKStickerContentView.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKEmojiContentView : WKStickerContentView

// emoji点击
@property(nonatomic,copy) void(^onEmoji)(WKEmotion *emoji);


@end

NS_ASSUME_NONNULL_END

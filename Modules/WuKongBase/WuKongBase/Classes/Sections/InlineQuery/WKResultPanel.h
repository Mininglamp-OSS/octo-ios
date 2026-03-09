//
//  WKResultPanel.h
//  WuKongBase
//
//  Created by tt on 2021/11/9.
//

#import <UIKit/UIKit.h>

#import "WKInlineQueryResult.h"



NS_ASSUME_NONNULL_BEGIN

typedef void(^WKLoadMoreCallback)(WKInlineQueryResult *result,NSError *error);

@interface WKResultPanel : UIView

@property(nonatomic,copy) void(^loadMore)(NSString *nextOffset,WKLoadMoreCallback  callback);

@end

NS_ASSUME_NONNULL_END

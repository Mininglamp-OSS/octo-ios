//
//  WKSearchMessageCell.h
//  WuKongBase
//
//  Created by tt on 2020/5/10.
//

#import "WKFormItemCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSearchMessageModel : WKFormItemModel

@property(nonatomic,strong) WKChannel *channel; // 显示的频道
@property(nonatomic,strong) NSNumber *messageCount; // 消息数量
@property(nonatomic,copy) NSString *content;
@property(nonatomic,copy) NSString *keyword;
@property(nonatomic,assign) NSInteger timestamp; // 消息时间


@end

@interface WKSearchMessageCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END

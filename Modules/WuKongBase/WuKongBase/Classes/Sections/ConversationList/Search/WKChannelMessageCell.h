//
//  WKChannelMessageCell.h
//  WuKongBase
//
//  Created by tt on 2020/8/14.
//

#import <WuKongBase/WuKongBase.h>
#import "WKFormItemCell.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKChannelMessageModel : WKFormItemModel

@property(nonatomic,copy) NSString *avatar; // 头像
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSNumber *timestamp;
@property(nonatomic,copy) NSString *content;
@property(nonatomic,copy) NSString *keyword;


@end

@interface WKChannelMessageCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END

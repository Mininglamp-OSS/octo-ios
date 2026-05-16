//
//  WKAvatarTitleCell.h
//  WuKongBase
//
//  Created by tt on 2022/11/7.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKAvatarTitleModel : WKFormItemModel

@property(nonatomic,copy) NSString *avatar;
@property(nonatomic,copy) NSString *name;


@end

@interface WKAvatarTitleCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END

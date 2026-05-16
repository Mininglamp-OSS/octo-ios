//
//  WKContactsAddMyShortCell.h
//  WuKongBase
//
//  Created by tt on 2020/6/22.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKContactsAddMyShortModel : WKFormItemModel

@property(nonatomic,copy) NSString *value;


/// 二维码点击
@property(nonatomic,strong) void(^onQRCode)(void);

@end

@interface WKContactsAddMyShortCell : WKCell


@end

NS_ASSUME_NONNULL_END

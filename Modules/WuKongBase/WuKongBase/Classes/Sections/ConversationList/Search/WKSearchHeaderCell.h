//
//  WKSearchHeaderCell.h
//  WuKongBase
//
//  Created by tt on 2020/4/25.
//

#import <WuKongBase/WuKongBase.h>
#import "WKFormItemCell.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKSearchHeaderModel : WKFormItemModel

@property(nonatomic,copy) NSString *title;

@end

@interface WKSearchHeaderCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END

//
//  WKLabelItemSelectCell.h
//  WuKongBase
//
//  Created by tt on 2020/12/11.
//

#import "WKLabelItemCell.h"

NS_ASSUME_NONNULL_BEGIN


@interface WKLabelItemSelectModel : WKLabelItemModel

@property(nonatomic,assign) BOOL selected;

@end

@interface WKLabelItemSelectCell : WKLabelItemCell

@end

NS_ASSUME_NONNULL_END

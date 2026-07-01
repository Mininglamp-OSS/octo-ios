//
//  WKChannelHistoryMediaGridCell.h
//  WuKongBase
//
//  "图片视频" tab 网格 cell。九宫格风格（3 列）+ 视频时长角标。
//

#import <UIKit/UIKit.h>
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistoryMediaGridCell : UICollectionViewCell
+ (NSString *)reuseIdentifier;
- (void)applyItem:(WKChannelHistorySearchItem *)item;
@end

NS_ASSUME_NONNULL_END

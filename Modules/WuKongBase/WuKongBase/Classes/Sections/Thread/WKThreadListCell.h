//
//  WKThreadListCell.h
//  WuKongBase
//

#import <UIKit/UIKit.h>

@class WKThreadModel;

NS_ASSUME_NONNULL_BEGIN

@interface WKThreadListCell : UITableViewCell

- (void)refreshWithModel:(WKThreadModel *)model;

@end

NS_ASSUME_NONNULL_END

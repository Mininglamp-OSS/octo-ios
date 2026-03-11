//
//  WKSpacePopupView.h
//  WuKongBase
//
//  Created by Claude on 2026/03/11.
//

#import <UIKit/UIKit.h>
#import "WKSpaceEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSpacePopupView : UIView

@property(nonatomic,copy) void(^onSpaceSelected)(WKSpaceEntity *space);
@property(nonatomic,copy) void(^onDismiss)(void);
@property(nonatomic,copy) NSString *currentSpaceId;

- (void)showFromView:(UIView *)anchorView;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END

//
//  WKDragModalView.h
//  WuKongBase
//
//  Created by tt on 2021/10/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKDragModalView : UIView

@property(nonatomic,weak) UIView *targetView;

@property(nonatomic,assign) CGFloat minHeight;

-(void) reset;

@end

NS_ASSUME_NONNULL_END

//
//  LMOnlineBadgeView.h
//  WuKongBase
//
//  Created by tt on 2020/8/27.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKOnlineBadgeView : UIView
@property(nonatomic,copy,nullable) NSString *tip;
+(instancetype) initWithTip:(NSString* __nullable)tip;
@end

NS_ASSUME_NONNULL_END

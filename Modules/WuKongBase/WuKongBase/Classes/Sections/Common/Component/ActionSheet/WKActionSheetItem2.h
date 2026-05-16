//
//  WKActionSheetItem2.h
//  WuKongBase
//
//  Created by tt on 2020/6/21.
//

#import <UIKit/UIKit.h>
#import "UIView+WK.h"
typedef void(^onItemClick)(void);
NS_ASSUME_NONNULL_BEGIN

@interface WKActionSheetItem2 : UIView
// 是否显示底部线条
@property(nonatomic,assign) BOOL showBottomLine;

@end

@interface WKActionSheetTipItem2 : WKActionSheetItem2

@property(nonatomic,strong) UILabel *tipLbl;

+(WKActionSheetTipItem2*) initWithTip:(NSString*)tip;

@end

@interface WKActionSheetButtonItem2 : WKActionSheetItem2
@property(nonatomic,strong) onItemClick onItemClick;
+(WKActionSheetButtonItem2*) initWithTitle:(NSString*)title onClick:(onItemClick)onItemClick;
+ (WKActionSheetButtonItem2 *)initWithAlertTitle:(NSString *)alertTitle onClick:(onItemClick)onItemClick;

@end

@interface WKActionSheetButtonSubtitleItem2 : WKActionSheetItem2
@property(nonatomic,strong) onItemClick onItemClick;
+(WKActionSheetButtonItem2*) initWithTitle:(NSString*)title subtitle:(NSString*)subtitle onClick:(onItemClick)onItemClick;

@end

@interface WKActionSheetCancelItem2 : WKActionSheetItem2
+ (WKActionSheetCancelItem2 *)initWithTitle:(NSString *)title onClick:(onItemClick)onItemClick;
@end


NS_ASSUME_NONNULL_END

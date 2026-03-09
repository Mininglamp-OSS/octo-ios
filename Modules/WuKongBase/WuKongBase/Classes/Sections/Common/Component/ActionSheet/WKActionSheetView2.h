//
//  WKActionSheetView2.h
//  WuKongBase
//
//  Created by tt on 2020/6/21.
//

#import <UIKit/UIKit.h>
#import "WKActionSheetItem2.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKActionSheetView2 : UIView

@property(nonatomic,copy) void(^onHide)(void);

/// 初始化
/// @param tip 提示内容
+(WKActionSheetView2*) initWithTip:(NSString* __nullable)tip;


/// 初始化
/// @param tip 提示内容
/// @param cancelBtnTitle 取消标题
+(WKActionSheetView2*) initWithTip:(NSString* __nullable)tip cancel:(NSString* __nullable)cancelBtnTitle;


/// 初始化
/// @param cancelBtnTitle 取消标题
+(WKActionSheetView2*) initWithCancel:(NSString* __nullable)cancelBtnTitle;


/// 添加item
/// @param item <#item description#>
-(void) addItem:(WKActionSheetItem2*)item;

/// 显示
-(void) show;
///  隐藏
-(void) hide;



@end

NS_ASSUME_NONNULL_END

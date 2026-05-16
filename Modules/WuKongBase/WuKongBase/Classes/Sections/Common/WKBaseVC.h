//
//  WKBaseVC.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import <UIKit/UIKit.h>
#import "WKBaseVM.h"
#import "WKNavigationBar.h"
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKViewConfigChangeTypeUnknown, // 未知
    WKViewConfigChangeTypeStyle, // 样式 （深色模式，亮色模式）
    WKViewConfigChangeTypeLang, // 多语言
    WKViewConfigChangeTypeModule, // 模块发生改变
} WKViewConfigChangeType;

@interface WKFinishButton : UIButton

@end

@interface WKBaseVC<__covariant ObjectType:WKBaseVM*> : UIViewController

@property(nonatomic,strong) WKNavigationBar *navigationBar; // 自定义的导航栏

@property(nonatomic,strong,nullable) UIView *rightView; // 导航栏右边视图

@property(nonatomic,strong) WKFinishButton *finishBtn; // 完成按钮

@property(nonatomic,assign,readonly) BOOL largeTitle; // 是否开启大标题模式

-(instancetype) initWithViewModel:(WKBaseVM*)vm;

@property(nonatomic,strong) ObjectType viewModel;

@property(nonatomic,strong) WKBaseVM *baseVM;


/// 获取导航栏底部距离
-(CGFloat) getNavBottom;
// 可视区域的frame
-(CGRect) visibleRect;


/// 返回点击
-(void) backPressed;


/// 视图配置发送变化
/// @param type 变化类型
-(void) viewConfigChange:(WKViewConfigChangeType)type;


/// 多语言标题 ，当多语言发送变化的时候会调用此标题
-(NSString*) langTitle;
@end

NS_ASSUME_NONNULL_END

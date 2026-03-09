//
//  WKMultiplePanel.h
//  WuKongBase
//  多选面板
//  Created by tt on 2020/10/11.
//

#import <UIKit/UIKit.h>
@class WKMultiplePanel;
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKMultipActionNone,
    WKMultipActionDelete, // 删除
    WKMultipActionForward, // 逐条转发
    WKMultipActionMergeForward, // 合并转发
    
} WKMultipAction;

@protocol WKMultiplePanelDelegate <NSObject>

@optional


/// 多选面板行为
/// @param panel <#panel description#>
/// @param action <#action description#>
-(void) multiplePanel:(WKMultiplePanel*)panel action:(WKMultipAction)action;

@end

@interface WKMultiplePanel : UIView

@property(nonatomic,weak) id<WKMultiplePanelDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

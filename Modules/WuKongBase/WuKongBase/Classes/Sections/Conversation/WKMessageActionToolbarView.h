//
//  WKMessageActionToolbarView.h
//  WuKongBase
//
//  Created by tt on 2021/9/24.
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKMessageActionToolbarView : UIView

-(instancetype) initWithToolbarMenus:(NSArray<WKMessageLongMenusItem*>*)toolbarMenus;

@property(nonatomic,copy) void(^onClick)(WKMessageLongMenusItem *menusItem);

@end

NS_ASSUME_NONNULL_END

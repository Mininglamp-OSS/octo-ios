//
//  WKTabbar.h
//  WuKongBase
//
//  Created by tt on 2025/2/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKTabbarItem : NSObject

-(id) initWithTitle:(NSString*)title onClick:(void(^)(void))onClick;

@property(nonatomic,copy) NSString *title; // item标题
@property(nonatomic,assign) BOOL selected; // 是否被选中
@property(nonatomic,copy) void(^onClick)(void); // 点击

@end

@interface WKTabbar : UIView

-(id) initWithItems:(NSArray<WKTabbarItem*>*)items width:(CGFloat)width;

@end



NS_ASSUME_NONNULL_END

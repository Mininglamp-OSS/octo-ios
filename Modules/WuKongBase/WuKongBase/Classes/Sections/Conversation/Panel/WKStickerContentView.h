//
//  WKStickerContentView.h
//  WuKongBase
//
//  Created by tt on 2020/2/1.
//

#import <Foundation/Foundation.h>
#import "WKConversationContext.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKStickerContentView : UIView

@property(nonatomic,weak) id<WKConversationContext> context;

/**
 tab的icon图标
 
 @return <#return value description#>
 */
@property(nonatomic,strong) UIImage *tabIcon;


/**
 自定义tab view
 */
@property(nonatomic,strong) UIView *customTabView;

@property(nonatomic,assign) BOOL selected; // 面板是否被选中

-(void) loadData;

@end

NS_ASSUME_NONNULL_END

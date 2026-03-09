//
//  WKContextMenusVC.h
//  WuKongBase
//
//  Created by tt on 2022/6/11.
//

#import <WuKongBase/WuKongBase.h>
NS_ASSUME_NONNULL_BEGIN


@interface WKMessageReactionModel : NSObject

@property(nonatomic,copy) NSString *reactionName;

@property(nonatomic,copy) NSString *reactionURL;

-(instancetype) initWithReactionName:(NSString*) reactionName reactionURL:(NSString*)reactionURL;

@end


@interface WKContextMenusVC : NSObject


@property(nonatomic,strong) UIView *focusedView; // 消息的view
// 回应item点击
@property(nonatomic,copy) void(^onReactionItem)(WKMessageReactionModel* model);

@property (nonatomic,copy) void(^disMissAction)(void);

@property(nonatomic,weak) id delegate;

//- (instancetype)initWithFocusedView:(UIView*)focusedView toolbarMenus:(NSArray<WKMessageLongMenusItem*>*)toolbarMenus conversationContext:(id<WKConversationContext>)conversationContext;

- (instancetype)initWithFocusedView:(UIView*)focusedView toolbarMenus:(NSArray<WKMessageLongMenusItem*>*)toolbarMenus conversationContext:(id<WKConversationContext>)conversationContext originalProjectedContentViewFrame:(CGRect)originalProjectedContentViewFrame;

-(void) presentOnWindow:(UIWindow*)window;

-(void) dismiss;

-(void) updateFocusedView:(UIView*)focusedView;

@end

NS_ASSUME_NONNULL_END

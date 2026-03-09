//
//  WKConversationListSelectVM.h
//  WuKongBase
//
//  Created by tt on 2020/9/28.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN
@class WKConversationListSelectVM;
@protocol WKConversationListSelectVMDelegate <NSObject>

@optional


/// 被选中的最近会话
/// @param vm <#vm description#>
/// @param channels <#channels description#>
-(void) conversationListSelectVM:(WKConversationListSelectVM*)vm didSelected:(NSArray<WKChannel*>*)channels;

@end

@interface WKConversationListSelectVM : WKBaseTableVM

@property(nonatomic,weak) id<WKConversationListSelectVMDelegate> delegate;

/// 是否开启多选
@property(nonatomic,assign) BOOL multiple;

@end

NS_ASSUME_NONNULL_END

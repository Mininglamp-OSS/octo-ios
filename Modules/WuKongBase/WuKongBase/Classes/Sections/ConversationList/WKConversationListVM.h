//
//  WKConversationListVM.h
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import <Foundation/Foundation.h>
#import "WKConversationWrapModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationListVM : NSObject

+ (WKConversationListVM *)shared;


-(void) reset; // 重置数据
/**
 加载最近会话列表
 */
-(void) loadConversationList:(void(^)(void)) finished;


/**
 最近会话数量

 @return <#return value description#>
 */
-(NSInteger) conversationCount;


/**
 最近会话列表数据

 @return <#return value description#>
 */
-(NSArray<WKConversationWrapModel*> *) conversationList;


/**
 排序
 */
-(void) sortConversationList;
/**
 获取频道会话的下表

 @param channel <#channel description#>
 @return <#return value description#>
 */
-(NSInteger) indexAtChannel:(WKChannel*)channel;


/**
 获取频道对应的z最近会话对象

 @param channel <#channel description#>
 @return <#return value description#>
 */
-(WKConversationWrapModel*) modelAtChannel:(WKChannel*) channel;

-(WKConversationWrapModel*) modelAtIndex:(NSInteger)index;

/**
 取代频道最近会话model

 @param model <#model description#>
 @param channel <#channel description#>
 */
-(void) replaceAtChannel:(WKConversationWrapModel*)model atChannel:(WKChannel*)channel;

-(void) replaceObjectAtIndex:(NSInteger)index withObject:(WKConversationWrapModel*)model;
/**
 移除指定频道的会话

 @param channel <#channel description#>
 */
-(void) removeAtChannnel:(WKChannel*)channel;

-(void) removeAtIndex:(NSInteger)index;


/// 移除所有会话
-(void) removeAll;
/**
 插入会话

 @param model <#model description#>
 @param insert <#insert description#>
 */
-(void) insert:(WKConversationWrapModel*)model atIndex:(NSInteger)insert;

-(NSInteger) insert:(WKConversationWrapModel*)model;


/**
  获取真正需要显示的conversation对象（如果最近会话属于某个最近会话的子类 其实真正要显示的是这个父类的最近会话信息）
 */
-(WKConversationWrapModel*) getRealShowConversationWrap:(WKConversationWrapModel*) wrapModel;
/**
  获取插入位置
 */
-(NSInteger) findInsertPlace:(WKConversationWrapModel*)model;

/**
 获取指定下标的最近会话对象

 @param index <#index description#>
 @return <#return value description#>
 */
-(WKConversationWrapModel*) conversationAtIndex:(NSInteger)index;


/// 移除最近会话
/// @param index <#index description#>
-(void) removeConversationAtIndex:(NSInteger)index;


/// 有会话置顶
-(BOOL) hasConversationTop;

/**
 获取所有未读数量

 @return <#return value description#>
 */
-(NSInteger) getAllUnreadCount;

@end

NS_ASSUME_NONNULL_END

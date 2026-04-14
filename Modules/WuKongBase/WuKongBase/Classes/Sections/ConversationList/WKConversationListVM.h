//
//  WKConversationListVM.h
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import <Foundation/Foundation.h>
#import "WKConversationWrapModel.h"
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKConversationFilterType) {
    WKConversationFilterGroup = 0,   // 群组
    WKConversationFilterPrivate = 1, // 私聊
};

@interface WKConversationListVM : NSObject

/// 当前过滤类型（群组/私聊）
@property (nonatomic, assign) WKConversationFilterType filterType;

+ (WKConversationListVM *)shared;


-(void) reset; // 重置数据

/// sync完成后调用：记录当前VM中的群聊channelId作为"当前空间合法群聊"白名单
/// shouldShowConversation: 中会用此白名单过滤其他空间的群聊
-(void) snapshotSyncedGroupIds;

/// 将群聊添加到当前空间白名单（用于群聊创建后立即显示在会话列表）
-(void) addGroupToWhitelist:(NSString*)channelId;

/// 检查群聊是否在当前空间白名单中
/// 白名单未初始化（首次sync前）时返回YES（暂不过滤）
-(BOOL) isGroupInWhitelist:(NSString*)channelId;
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


/// 拉取所有群组的子区数量
-(void) fetchThreadCountsForGroups;

/// 重建过滤列表（filterType 变更或数据增删后调用）
-(void) rebuildFilteredList;

/// 获取群组类未读数
-(NSInteger) getGroupUnreadCount;

/// 获取私聊类未读数
-(NSInteger) getPrivateUnreadCount;

/// 刷新指定群组的子区数量
-(void) refreshThreadCountForGroups:(NSSet<NSString*>*)groupNos;

/// 有会话置顶
-(BOOL) hasConversationTop;

/**
 获取所有未读数量

 @return <#return value description#>
 */
-(NSInteger) getAllUnreadCount;

@end

NS_ASSUME_NONNULL_END

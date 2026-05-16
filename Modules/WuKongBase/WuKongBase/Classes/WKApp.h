//
//  WKApp.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
// 此类为全局APP方法
//

#import <Foundation/Foundation.h>
#import "WKLoginInfo.h"
#import "WKEndpoint.h"
#import "WKMessageRegistry.h"
#import <SDWebImage/SDWebImage.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConversationContext.h"
#import "WKAppConfig.h"
#import "WKEndpointManager.h"
#import "WKStickerPackage.h"
#import <PromiseKit/PromiseKit.h>
NS_ASSUME_NONNULL_BEGIN


@protocol WKAppDelegate <NSObject>

@optional


/// app已登出
-(void) appLogout;

// app登录成功
-(void) appLoginSuccess;

@end

@interface WKApp : NSObject
+ (WKApp *)shared;

@property(nonatomic,strong) WKEndpointManager *endpointManager;


/**
 添加委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKAppDelegate>) delegate;


/**
 移除委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKAppDelegate>) delegate;

/**
 配置信息
 */
@property(nonatomic,strong) WKAppConfig *config;

// app远程配置
@property(nonatomic,strong) WKAppRemoteConfig *remoteConfig;

/**
 首页视图控制器（APP的首页）
 */
@property(nonatomic,strong) UIViewController*(^getHomeViewController)(void);

/**
 是否已登录

 @return <#return value description#>
 */
-(BOOL) isLogined;


/**
 当前用户信息
 */
@property(nonatomic,strong,readonly) WKLoginInfo *loginInfo;


/**
 消息登记管理
 */
@property(nonatomic,strong,readonly) WKMessageRegistry *messageRegitry;


/// 图片缓存
@property(nonatomic,strong) SDImageCache *imageCache;


/// 当前聊天的频道
@property(nonatomic,weak) WKChannel *currentChatChannel;


/// 当前打开的最近会话上下文
@property(nonatomic,weak) id<WKConversationContext> conversationContext;

@property(nonatomic,strong) NSArray<WKSticker*> *collectStickers; // 收藏的表情
@property(nonatomic,assign) BOOL collectStickerRequested; // 是否已经成功请求了收藏表情的数据

// app初始化
-(void) appInit;

-(BOOL) appOpenURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

-(BOOL) appContinueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

/**
 登出
 */
-(void) logout;

/**
 注册端点
 @param endpoint 端点对象
 */
-(void) registerEndpoint:(WKEndpoint*)endpoint;

-(void) unregisterEndpointWithCategory:(NSString*)category;

-(WKEndpoint*) getEndpoint:(NSString*)sid;


/**
 调用endpoint

 @param endpointSID endpoint的 sid
 @param param 传入参数
 @return 返回
 */
-(id) invoke:(NSString*)endpointSID param:(__nullable id)param;
-(NSArray*) invokes:(NSString*)category param:(__nullable id)param;

/**
 设置方法

 @param sid poit唯一id
 @param handler 处理方法
 */
-(void) setMethod:(NSString*)sid handler:(WKHandler) handler;
-(void) setMethod:(NSString*)sid handler:(WKHandler) handler category:(NSString* __nullable)category;
-(void) setMethod:(NSString*)sid handler:(WKHandler) handler category:(NSString* __nullable)category sort:(int)sort;


/// 是否有指定的方法
/// @param sid <#sid description#>
-(BOOL) hasMethod:(NSString*)sid;


/**
 获取指定类别的端点

 @param category point类别
 @return <#return value description#>
 */
-(NSArray<WKEndpoint*>*) getEndpointsWithCategory:(NSString*)category;


/// 注册消息cell和content
/// @param cellClass 消息cell
/// @param messageContentClass 消息content
-(void) registerCellClass:(Class)cellClass forMessageContntClass:(Class)messageContentClass;


/// 注册消息
/// @param cellClass 消息cell
/// @param contentType 消息正文类型
-(void) registerCellClass:(Class)cellClass contentType:(NSInteger)contentType;


/// 获取消息的cell
/// @param contentType <#contentType description#>
-(Class) getMessageCell:(NSInteger)contentType;
/**
 加载图片

 @param name 图片名称
 @param moduleID 模块唯一ID
 @return <#return value description#>
 */
-(UIImage*) loadImage:(NSString*)name moduleID:(NSString*)moduleID;

/**  获取某个module的资源bundle*/
-(NSBundle*) resourceBundle:(NSString*)moduleID;

-(NSBundle*) resourceBundleWithClass:(Class)cls;


/// 获取完整的图片路径
/// @param path 路径
-(NSURL*) getImageFullUrl:(NSString*)path;


/// 获取文件的完整路径
/// @param path <#path description#>
-(NSURL*) getFileFullUrl:(NSString*)path;


/// 添加允许转发的消息（添加后在聊天页面长按将不会显示“转发”选项）
/// @param contentType <#contentType description#>
-(void) addMessageAllowForward:(NSInteger)contentType;


/// 添加允许复制的消息（添加后在聊天页面长按将不会显示"复制"选项）
/// @param contentType <#contentType description#>
-(void) addMessageAllowCopy:(NSInteger)contentType;

/// 添加允许收藏的消息（添加后在聊天页面长按将不会显示"收藏"选项）
/// @param contentType <#contentType description#>
-(void) addMessageAllowFavorite:(NSInteger)contentType;


/// 是否允许转发
/// @param contentType <#contentType description#>
-(BOOL) allowMessageForward:(NSInteger)contentType;


/// 是否允许复制
/// @param contentType <#contentType description#>
-(BOOL) allowMessageCopy:(NSInteger)contentType;


/// 是否允许收藏
/// @param contentType <#contentType description#>
-(BOOL) allowMessageFavorite:(NSInteger)contentType;

// 计算视频缓存目录大小
- (unsigned long long)calculateVideoCachedSizeWithError:(NSError **)error;

// 清空视频缓存
-(void) cleanVideoCache;


// 跳到聊天页面
-(void) pushConversation:(WKChannel*)channel;

- (UIWindow*) findWindow;


// 添加频道头像更新通知
-(void) addChannelAvatarUpdateNotify:(id)observer selector:(SEL)sel;

// 移除频道头像更新通知
-(void) removeChannelAvatarUpdateNotify:(id)observer;

// 通知频道头像更新
-(void) notifyChannelAvatarUpdate:(WKChannel*)channel;

// 加载当前用户收藏的表情
-(AnyPromise*) loadCollectStickers;

// 按需加载当前用户收藏的表情
-(AnyPromise*) loadCollectStickersIfNeed;

// 是否是系统账号(系统通知和文件助手)
-(BOOL) isSystemAccount:(NSString*)uid;

@end

NS_ASSUME_NONNULL_END


 
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeyShortNo; // 短编号
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeyScreenshot; // 截屏通知
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeyForbiddenAddFriend; // 禁止互加好友
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeyRevokeRemind; // 撤回通知
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeyJoinGroupRemind; // 进群通知
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeyChatPwd; // 聊天密码

FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeySource; // 来源
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable WKChannelExtraKeyVercode; // 加好友验证码

FOUNDATION_EXPORT WKChannelExtraKey const _Nullable WKChannelExtraKeyAllowViewHistoryMsg; // 允许新成员查看群历史消息

FOUNDATION_EXPORT WKChannelExtraKey const _Nullable WKChannelExtraKeyRemark; // 备注


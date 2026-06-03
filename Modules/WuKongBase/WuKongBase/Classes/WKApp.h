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
 图文混排发送（RichText=14）：把多张已压缩的图片 + 附带文本聚合成单条消息。

 用于主聊天「相册选图时输入框已有文本」场景——避免图发出而文字被静默丢弃。每张图先
 写入临时文件再走与分享入口一致的上传/构造链路（图 block 在前 + text block 在后）。

 与分享入口的根本区别：本方法在**活跃会话上下文**内发送，最终落地走 `context` 的
 `sendMessage:`——与原相册单图发送（`[context sendMessage:WKImageContent]`）完全同一
 路径，从而保留回执设置 / 阅后即焚 expiry / spaceId / 父子频道 topic 路由 / reply
 元数据 / 本地 tracing + 列表插入等全部会话语义；绝不退化为 `forwardMessage:`（裸
 save+send）那样绕过这些装饰。

 原子性（全发或全不发）：进入聚合发送前先校验 `imageDatas.count == assetCount`
 （压缩阶段未丢图），再要求**每一张**图都成功落盘；任一条件不满足 → 整条中止、弹
 「发送失败」HUD、回调 `onFailure` 恢复草稿。绝不静默只发其中几张（违反原子性声明）。

 调用方应在调用前清空输入框（避免重复发送）；若任一环节失败，`onFailure` 会在主线程
 回调，调用方据此把文本恢复到输入框，保证文字绝不被静默丢弃。

 @param imageDatas 已压缩的图片二进制（与相册回调一致，顺序即展示顺序）
 @param assetCount 用户实际选中的图片资产数量（用于原子性校验：压缩阶段是否丢图）
 @param extraText  输入框待发文本（调用方保证非空白）
 @param context    当前会话上下文（最终消息走 `context.sendMessage:`，channel 取自其中）
 @param onFailure  发送失败时主线程回调（用于恢复输入框草稿），可为 nil
 */
-(void) sendRichTextMixedImageDatas:(NSArray<NSData*>*)imageDatas
                         assetCount:(NSUInteger)assetCount
                          extraText:(NSString*)extraText
                          inContext:(id<WKConversationContext>)context
                          onFailure:(void(^_Nullable)(void))onFailure;

/**
 相册选图「是否由图文聚合路径接管」决策（footgun 守卫，纯函数，便于单测）：仅当选中
 全为图片、至少选了一张（assetCount>0）、且输入框存在非空白待发文本时，才由聚合路径
 接管（把图 + 文本聚合成单条 RichText(=14)）；否则走原逐条发送路径（纯图 / 含视频 /
 无文本零回归）。

 关键：决策基于**用户实际选中的图片资产数**（assetCount），不依赖压缩结果数——只要
 选了图且有文本就必须接管。绝不能因「压缩丢图」（压缩后图变少甚至为 0）退回原逐条
 路径，否则 (a) 文本被原路径丢掉（即 #21 footgun），(b) 原逐条 loop 会按 assets 下标
 索引 images 数组越界崩溃。压缩丢图的原子性在接管后的发送方法内校验
 （`imageDatas.count == assetCount` 不满足 → 整条失败并恢复草稿）。

 @param allImages   选中项是否全部为图片（含「至少选了一项」的语义由调用方保证传入）
 @param assetCount  用户实际选中的图片资产数量
 @param pendingText 输入框当前文本（未 trim，内部做空白裁剪判定）
 @return YES 表示应由图文聚合路径接管
 */
+ (BOOL)shouldAggregateAlbumImagesWithText:(BOOL)allImages
                                assetCount:(NSUInteger)assetCount
                               pendingText:(nullable NSString *)pendingText;

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

/// 读取宿主 app 的主图标（用于关于页 / 登录页等需要展示 app logo 的位置）。
/// 解析顺序与 WKAboutVC 老实现一致, 抽公共方法避免重复:
///   1. Info.plist 新格式 CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName
///   2. 旧格式 CFBundleIconFiles 数组的最后一项（习惯放最大尺寸）
///   3. 通用名称 "AppIcon"
///   4. 兜底 launch screen 用的 "lanch_logo" imageset
/// 任何一步取到非 nil 即返回。所有都失败时返回 nil, 调用侧自行决定是否展位图。
+ (nullable UIImage *)appLaunchIcon;

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
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeyJoinGroupRemind; // 进群通知
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeyChatPwd; // 聊天密码

FOUNDATION_EXPORT WKChannelExtraKey const _Nullable  WKChannelExtraKeySource; // 来源
FOUNDATION_EXPORT WKChannelExtraKey const _Nullable WKChannelExtraKeyVercode; // 加好友验证码

FOUNDATION_EXPORT WKChannelExtraKey const _Nullable WKChannelExtraKeyAllowViewHistoryMsg; // 允许新成员查看群历史消息

FOUNDATION_EXPORT WKChannelExtraKey const _Nullable WKChannelExtraKeyRemark; // 备注


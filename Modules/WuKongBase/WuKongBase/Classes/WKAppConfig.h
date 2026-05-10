//
//  WKAppConfig.h
//  WuKongBase
//
//  Created by tt on 2021/8/25.
//

#import <Foundation/Foundation.h>
#import "WKModel.h"
#import "WKRTCIceServer.h"
#import "WKOidcProviderConfig.h"
@class WKAppModuleResp;

@class WKThemeContextMenu;
typedef enum : NSUInteger {
    WKSystemStyleUnknown, // 未知样式
    WKSystemStyleLight, // 亮色模式
    WKSystemStyleDark, // 深色模式
} WKSystemStyle; // 系统样式


NS_ASSUME_NONNULL_BEGIN

@interface WKAppConfig : NSObject

// app名称
@property(nonatomic,copy) NSString *appName;

// appstore的appID 用户跳转
@property(nonatomic,copy) NSString *appID;
// 短编号名称
@property(nonatomic,copy) NSString *shortName;
// app的 Schema 前缀 例如 wukong (botgate://friend/apply)
@property(nonatomic,copy) NSString *appSchemaPrefix;

// 应用bundleID
@property(nonatomic,copy) NSString *bundleID;

@property(nonatomic,assign) WKSystemStyle style;

@property(nonatomic,copy) NSString *langue; // 获取系统语言


/// 深色模式是否跟随系统
@property(nonatomic,assign) BOOL darkModeWithSystem;

// api基地址
@property(nonatomic,copy) NSString *apiBaseUrl;

/// 分布式开关 默认：关闭
@property(nonatomic,assign) BOOL clusterOn;

// 文件基地址 （文件上传地址）
@property(nonatomic,copy) NSString *fileBaseUrl;
// 文件预览地址(如果为空，则默认为fileBaseUrl的值)
@property(nonatomic,copy) NSString *fileBrowseUrl;
// 图片预览地址
@property(nonatomic,copy) NSString *imageBrowseUrl;
// 举报的html的url
@property(nonatomic,copy) NSString *reportUrl;
// 隐私协议地址
@property(nonatomic,copy) NSString *privacyAgreementUrl;
// 用户协议地址
@property(nonatomic,copy) NSString *userAgreementUrl;
// IM连接地址
@property(nonatomic,copy) NSString *connectURL;
// 扫码URL前缀，可以根据这个前缀判断是否是自己定义的二维码内容
@property(nonatomic,copy) NSString *scanURLPrefix;


/// 会话每页消息数量
@property(nonatomic,assign) int eachPageMsgLimit;

// 显示消息间隔
@property(nonatomic,assign) NSTimeInterval messageTipTimeInterval;
// 消息头像大小
@property(nonatomic,assign) CGSize messageAvatarSize;
// 头像大小
@property(nonatomic,assign) CGSize smallAvatarSize; // 小头像
@property(nonatomic,assign) CGSize middleAvatarSize; // 中头像
@property(nonatomic,assign) CGSize bigAvatarSize; // 大头像
// 消息列表头像大小
@property(nonatomic,assign) CGSize messageListAvatarSize;
// 消息正文最大宽度
@property(nonatomic,assign) CGFloat messageContentMaxWidth;
// 系统消息正文最大宽度
@property(nonatomic,assign) CGFloat systemMessageContentMaxWidth;

// 消息文本最大byte值 0 表示不限制
@property(nonatomic,assign) NSInteger messageTextMaxBytes;

// 未知消息的文本内容
@property(nonatomic,copy) NSString *unkownMessageText;
// 解密错误文本
@property(nonatomic,copy) NSString *signalErrorMessageText;

// db数据库文件前缀
@property(nonatomic,copy) NSString *dbPrefix;

// 会话设置里的成员头像大小
@property(nonatomic,assign) CGSize settingMemberAvatarSize;
// 文件存储目录
@property(nonatomic,copy) NSString *fileStorageDir;
// 图片缓存目录
@property(nonatomic,copy) NSString *imageCacheDir;
// 图片最大限制大小
@property(nonatomic,assign) NSUInteger imageMaxLimitBytes;

//默认头像
@property(nonatomic,strong) UIImage *defaultAvatar;

//默认占位图
@property(nonatomic,strong) UIImage *defaultPlaceholder;

//默认贴图占位图
@property(nonatomic,strong) UIImage *defaultStickerPlaceholder;

// ---------- 样式 ----------
// APP背景颜色
@property(nonatomic,strong) UIColor *backgroundColor;
// cell的背景颜色
@property(nonatomic,strong) UIColor *cellBackgroundColor;
// APP主题颜色
@property(nonatomic,strong) UIColor *themeColor;
// 默认文本颜色
@property(nonatomic,strong) UIColor *defaultTextColor;
@property(nonatomic,strong) UIFont *defaultFont; // 默认字体

@property(nonatomic,strong) UIColor *lineColor; // 线条颜色

// ---------- 消息相关配置 ----------
@property(nonatomic,assign) CGFloat messageTextFontSize; // 文本消息字体大小
@property(nonatomic,assign) CGFloat messageTipTimeFontSize; // 消息时间字体大小
@property(nonatomic,strong) UIColor *messageSendTextColor; // 发送消息文本颜色
@property(nonatomic,strong) UIColor *messageRecvTextColor; // 收取消息文本颜色
@property(nonatomic,strong) UIColor *messageTipColor; // 消息内的提示文字颜色
@property(nonatomic,strong) UIColor *warnColor; // 消息内的提示文字颜色

// 提示文字的颜色
@property(nonatomic,strong) UIColor *tipColor;
// cell的footer提示字体大小（例如：群管理里的群聊邀请确认下面的提示）
@property(nonatomic,assign) CGFloat footerTipFontSize;


// ---------- 导航栏 ----------
@property(nonatomic,strong) UIColor *navBackgroudColor; // 导航栏背景颜色
@property(nonatomic,strong) UIColor *navBarButtonColor; //导航栏的bar按钮颜色
@property(nonatomic,strong) UIFont *navBarTitleFont; // 导航栏标题字体
@property(nonatomic,strong) UIColor *navBarTitleColor; //导航栏标题的颜色
@property(nonatomic,strong) UIColor *navBarSubtitleColor; //导航栏子标题的颜色
@property(nonatomic,assign) CGFloat navHeight; // 导航栏高度
- (UIColor *)navBackgroudColorWithAlpha:(CGFloat) alpha;




@property(nonatomic,strong) WKThemeContextMenu *contextMenu; // 上下文菜单主体


// app的字体
-(nullable UIFont*) appFontOfSize:(CGFloat)size;
-(nullable UIFont*) appFontOfSizeSemibold:(CGFloat)size;
-(nullable UIFont*) appFontOfSizeMedium:(CGFloat)size;

// 数据每页大小
@property(nonatomic,assign) NSInteger pageSize;

@property(nonatomic,assign) UIEdgeInsets visibleEdgeInsets;

@property(nonatomic,copy) NSString *inviteMsg; // 好友邀请消息

@property(nonatomic,copy) NSString *videoCacheDir; // 视频缓存目录

@property(nonatomic,copy) NSString *fileHelperUID; // 文件助手的uid
@property(nonatomic,copy) NSString *systemUID; // 系统通知的uid
@property(nonatomic,copy) NSString *botfatherUID; // BotFather的uid

// YUJ-219-A4: System bot UIDs whose conversations require per-Space message
// isolation. Comes from backend `common/appconfig` -> `system_bot_uids`;
// defaults to @[@"botfather", @"u_10000", @"fileHelper"] when the appconfig
// response does not include the field (keeps behavior usable when A2 backend
// isn't deployed yet). Callers should use
// `[[WKApp shared].config.systemBotUIDs containsObject:channelId]` instead of
// comparing against `botfatherUID` alone.
@property(nonatomic,copy) NSArray<NSString*> *systemBotUIDs;

// 对按钮增加主题样式
-(void) setThemeStyleButton:(UIButton*)btn;
// 导航栏增加样式
-(void) setThemeStyleNavigation:(UIView*)view;

@property(nonatomic,assign) BOOL takeScreenshotOn; // 截屏通知是否开启

@property(nonatomic,assign) NSTimeInterval defaultAnimationDuration; // 默认动画时间

@property(nonatomic,strong) NSArray<WKRTCIceServer*> *rtcIces; // rtc的ice配置

@end

@interface WKAppRemoteConfig : NSObject

@property(nonatomic,copy) NSString *webURL;
@property(nonatomic,assign) BOOL phoneSearchOff;
@property(nonatomic,assign) BOOL shortnoEditOff;
@property(nonatomic,assign) NSInteger revokeSecond; // 撤回时间
@property(nonatomic,assign) BOOL registerInviteOn; // 是否开启注册邀请
@property(nonatomic,assign) BOOL inviteSystemAccountJoinGroupOn; // 是否允许邀请系统账号加入群里

@property(nonatomic,assign) BOOL registerUserMustCompleteInfoOn; // 用户注册是否必须要完善信息后才能进入

@property(nonatomic,assign) BOOL threadOn; // 子区功能开关

@property(nonatomic,strong) NSArray<WKAppModuleResp*> *modules;

// YUJ-396 / GH dmwork-web#1174: OIDC provider 列表（appconfig.oidc_providers）.
// 每个 entry 的 accountUrl 按环境不同（accounts-test.imocto.cn on im-test,
// accounts.example.com on im-prod）。WKRealnameVerifyManager 从这里读账户页 URL,
// 不再硬编码 prod 常量。未下发时为 @[], 调用侧需有 toast 兜底。
@property(nonatomic,copy) NSArray<WKOidcProviderConfig*> *oidcProviders;

@property(nonatomic,assign) BOOL requestSuccess; // 请求远程配置是否成功
@property(nonatomic,assign) BOOL requestAppModuleSuccess; // 请求app模块是否成功

/// 请求远程配置。可以安全多次调用：
///   - `requestSuccess == YES` → 立刻 callback(nil)
///   - 有 in-flight 请求 → 本 callback 挂到内部队列, 请求完成时一起 fire
///     （YUJ-396 R3 / Jerry-Xin #112 review warning: 老实现在 startRequest==YES
///       时会静默丢 callback, 导致调用侧（如 WKRealnameVerifyManager）无法等待
///       appconfig loading 完成）
///   - 未请求 → 本次起请求, callback 同样入队等完成
///
/// 失败场景会把 NSError 传给所有入队的 callback; 下一次调用 requestConfig:
/// 会重新发起请求（requestSuccess 还是 NO）。
-(void) requestConfig:(void(^__nullable)(NSError  * __nullable error))callback;

// 启用或关闭模块
-(void) modules:(NSString*)sid on:(BOOL)on;

// 模块是否启用
-(BOOL) moduleOn:(NSString*)sid;

// 用户是否有设置指定的模块
- (BOOL)moduleHasSetting:(NSString *)sid;

@end

@interface WKThemeContextMenu : NSObject

@property(nonatomic,strong) UIColor *primaryColor;

@end

typedef enum : NSInteger {
    WKAppModuleStatusDisable, // 不选中不可用
    WKAppModuleStatusEdit, // 选中可编辑
    WKAppModuleStatusNoEdit, // 选中 不可编辑
} WKAppModuleStatus;

@interface WKAppModuleResp : WKModel

@property(nonatomic,copy) NSString *sid; // 模块唯一id
@property(nonatomic,copy) NSString *name; // 模块名称
@property(nonatomic,copy) NSString *desc; // 模块描述
@property(nonatomic,assign) BOOL hidden; // 隐藏
@property(nonatomic,assign) NSInteger status; // 模块状态 1.可选 0.不可选 2.选中不可编辑


@end

NS_ASSUME_NONNULL_END

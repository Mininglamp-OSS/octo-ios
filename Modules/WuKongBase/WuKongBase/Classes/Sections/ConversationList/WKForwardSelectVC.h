//
//  WKForwardSelectVC.h
//  WuKongBase
//
//  转发选择会话页面（群聊/私聊 tab + 分组 + 子区）
//

#import "WKBaseVC.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKForwardSelectVC : WKBaseVC

/// 多选模式：逐个回调
@property (nonatomic, copy, nullable) void(^onSelect)(WKChannel *channel);

/// 多选模式：批量回调
@property (nonatomic, copy, nullable) void(^onConfirmChannels)(NSArray<WKChannel *> *channels);

/// 单选模式（外部分享场景：点击会话弹确认面板）
@property (nonatomic, assign) BOOL singleSelectMode;

/// 分享的文件信息（单选模式下用于确认面板展示文件预览）
@property (nonatomic, strong, nullable) NSArray<NSDictionary *> *shareFileInfos;

/// 单选确认回调（channel + 用户输入的附带文本）
@property (nonatomic, copy, nullable) void(^onSingleConfirm)(WKChannel *channel, NSString * _Nullable extraText);

/// 多选模式预选: 进入页面时这些 channel 默认已勾选, 用户可二次编辑(增/减)。
/// 可空。channelType + channelId 用于命中 cell, 命中不到的(数据未加载到当前 tab)
/// 也保留在内部 _checkedChannels, 提交时一并回调。
@property (nonatomic, copy, nullable) NSArray<WKChannel *> *preselectedChannels;

@end

NS_ASSUME_NONNULL_END

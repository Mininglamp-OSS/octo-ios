//
//  WKForwardDirectoryVC.h
//  WuKongBase
//
//  「新建会话」全量目录选择页：群聊（含可折叠子区）/ 联系人 / Bot 三个 tab + 搜索。
//  由转发选择页（WKForwardSelectVC）的「新建会话」入口进入，覆盖那些不在已有
//  会话列表里的目标。选中后走与转发页完全一致的回调完成转发。
//

#import "WKBaseVC.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKForwardDirectoryVC : WKBaseVC

/// 多选模式：逐个回调（与 WKForwardSelectVC 对齐，便于透传）
@property (nonatomic, copy, nullable) void(^onSelect)(WKChannel *channel);

/// 多选模式：批量回调
@property (nonatomic, copy, nullable) void(^onConfirmChannels)(NSArray<WKChannel *> *channels);

/// 单选模式（外部分享场景：点击目标弹确认面板）
@property (nonatomic, assign) BOOL singleSelectMode;

/// 分享的文件信息（单选模式下用于确认面板展示文件预览）
@property (nonatomic, strong, nullable) NSArray<NSDictionary *> *shareFileInfos;

/// 单选确认回调（channel + 用户输入的附带文本）
@property (nonatomic, copy, nullable) void(^onSingleConfirm)(WKChannel *channel, NSString * _Nullable extraText);

@end

NS_ASSUME_NONNULL_END

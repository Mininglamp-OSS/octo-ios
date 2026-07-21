//
//  WKGlobalSearchPickerVC.h
//  WuKongBase
//
//  通用「可搜索多选」子页：用于全局搜索筛选里的 发送者 / 所在群聊或子区 / 包含成员。
//  候选由外部 candidateProvider 提供（本地 DB friends/groups 搜索），与会话内搜索的
//  发送人选择器（花名册作用域）互补 —— 全局无单一频道，故走关键词候选。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 单个候选/已选项。id 为 uid（成员/发送者）或 channelId（群/子区）。
@interface WKGlobalSearchPickEntry : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *avatarUrl;
@property (nonatomic, assign) NSInteger channelType; // 群/子区候选带类型；成员为 0
+ (instancetype)entryWithId:(NSString *)identifier name:(NSString *)name avatarUrl:(nullable NSString *)avatarUrl channelType:(NSInteger)channelType;
@end

@class WKGlobalSearchPickerVC;

@interface WKGlobalSearchPickerVC : UIViewController

@property (nonatomic, copy) NSString *navTitle;
@property (nonatomic, copy, nullable) NSString *searchPlaceholder;
/// 预选项（用于回显名称 + 勾选态）。
@property (nonatomic, copy, nullable) NSArray<WKGlobalSearchPickEntry *> *preselected;
/// 候选提供者：输入 keyword（可空=初始列表），异步回调候选数组。
@property (nonatomic, copy) void (^candidateProvider)(NSString *keyword, void (^completion)(NSArray<WKGlobalSearchPickEntry *> *entries));
/// 完成回调：返回最终选中项。
@property (nonatomic, copy) void (^onFinish)(NSArray<WKGlobalSearchPickEntry *> *selected);

@end

NS_ASSUME_NONNULL_END

//
//  WKMergeForwardContent.h
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKMergeForwardContent : WKMessageContent

@property(nonatomic,copy,readonly) NSString *title; // 标题

@property(nonatomic,assign) WKChannelType channelType; // 频道类型
@property(nonatomic,strong) NSArray<NSDictionary*> *users; // 当channelType=1时有值 聊天用户集合 [{"uid":"xxx","name":"xxx"}]
@property(nonatomic,strong) NSArray<WKMessage*> *msgs; // 合并的消息集合

+(instancetype) msgs:(NSArray<WKMessage*>*)msgs users:(NSArray<NSDictionary*>*)users channelType:(WKChannelType)channelType;

@end

NS_ASSUME_NONNULL_END

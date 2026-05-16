//
//  WKChatDataProvider.h
//  Pods
//
//  Created by tt on 2022/5/27.
//
#import "WKSyncChannelMessageModel.h"
#ifndef WKChatDataProvider_h
#define WKChatDataProvider_h


#endif /* WKChatDataProvider_h */


NS_ASSUME_NONNULL_BEGIN
// 同步频道消息
typedef void(^WKSyncChannelMessageCallback)(WKSyncChannelMessageModel* __nullable syncChannelMessageModel,NSError * __nullable error);
typedef void (^WKSyncChannelMessageProvider)(WKChannel *channel,uint32_t startMessageSeq,uint32_t endMessageSeq,NSInteger limit,WKPullMode pullMode,WKSyncChannelMessageCallback callback);

// 扩展消息
typedef void(^WKSyncMessageExtraCallback)(NSArray<WKMessageExtra*>* __nullable results,NSError * __nullable error);
typedef void(^WKSyncMessageExtraProvider)(WKChannel *channel,long long extraVersion,NSInteger limit,WKSyncMessageExtraCallback callback);
typedef void(^WKUpdateMessageExtraCallback)(NSError *error);
typedef void(^WKUpdateMessageExtraProvider) (WKMessageExtra *newExtra,WKMessageExtra *oldExtra,WKUpdateMessageExtraCallback callback);

// 消息编辑
typedef void(^WKMessageEditCallback)(NSError * __nullable error);
typedef void(^WKMessageEditProvider)(WKMessageExtra *extra,WKMessageEditCallback callback);

NS_ASSUME_NONNULL_END

//
//  WKChannelHistorySenderPickerVC.h
//  WuKongBase
//
//  发送人选择子页：群/子区拉成员（子区使用父群），私聊本地合成 [自己,对方]。
//

#import <UIKit/UIKit.h>

@class WKChannel;
@class WKChannelHistorySenderPickerVC;

NS_ASSUME_NONNULL_BEGIN

/// 发送人简化模型。
@interface WKChannelHistorySenderEntry : NSObject
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *avatarUrl;
@end

@protocol WKChannelHistorySenderPickerVCDelegate <NSObject>
- (void)senderPickerVC:(WKChannelHistorySenderPickerVC *)vc didFinishWithUids:(NSArray<NSString *> *)uids;
@end

@interface WKChannelHistorySenderPickerVC : UIViewController

@property (nonatomic, strong) WKChannel *channel;
@property (nonatomic, copy) NSArray<NSString *> *selectedUids;
@property (nonatomic, weak, nullable) id<WKChannelHistorySenderPickerVCDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

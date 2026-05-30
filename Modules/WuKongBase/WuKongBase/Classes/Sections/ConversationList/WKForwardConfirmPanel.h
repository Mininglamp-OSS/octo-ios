//
//  WKForwardConfirmPanel.h
//  WuKongBase
//
//  转发/分享「发送给 xxx」底部确认面板。
//  从 WKForwardSelectVC 抽出，供转发选择页与全量目录页共用。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKForwardConfirmPanel : NSObject

/// 在 keyWindow 上弹出「发送给」确认面板。
/// @param channel  目标频道（仅用于展示头像，发送动作由 onSend 回调驱动）
/// @param name     目标显示名
/// @param isGroup  目标是否为群聊（显示 # 图标）
/// @param isThread 目标是否为子区（显示子区图标）
/// @param shareFileInfos 可选，外部分享文件/链接信息，用于展示预览卡片
/// @param onSend   点击「发送」回调，参数为用户附带输入的文本（可能为空）
+ (void)showForChannel:(WKChannel *)channel
                  name:(nullable NSString *)name
               isGroup:(BOOL)isGroup
              isThread:(BOOL)isThread
        shareFileInfos:(nullable NSArray<NSDictionary *> *)shareFileInfos
                onSend:(void(^)(NSString * _Nullable extraText))onSend;

@end

NS_ASSUME_NONNULL_END

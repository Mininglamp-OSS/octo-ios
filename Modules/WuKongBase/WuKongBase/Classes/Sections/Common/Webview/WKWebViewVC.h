//
//  WKWebViewVC.h
//  WuKongBase
//
//  Created by tt on 2020/4/3.
//

#import "WKBaseVC.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKWebViewVC : WKBaseVC

@property(nonatomic,strong) NSURL *url;
/// 文档页打开时使用的空间；nil 沿用 App 当前空间，空字符串清除旧空间上下文。
@property(nonatomic,copy,nullable) NSString *docsViewerSpaceId;

// 频道对象，如果是从聊天页面跳转到web请给channel赋值
@property(nonatomic,strong,nullable) WKChannel *channel;
@end

NS_ASSUME_NONNULL_END

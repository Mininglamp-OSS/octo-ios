//
//  WKUserAvatar.h
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import <UIKit/UIKit.h>
#import "WKImageView.h"

#define WKDefaultAvatarSize CGSizeMake(50.0f,50.0f)

NS_ASSUME_NONNULL_BEGIN

// 诊断开关：YES = 头像不自动播放动图，只显示第一帧。
// WKUserAvatar 内部用 WKImageView (SDAnimatedImageView 子类)，群里多个动图头像会
// 各自启动 CADisplayLink 持续解码 + setImage + 重绘，主线程被薅，表现为 100-150ms
// 周期 HANG（跟 GIF 7-10fps 帧率对得上）。排查完置 NO 即可。
extern const BOOL kDisableAvatarAnimation;

@interface WKUserAvatar : UIView

@property(nonatomic,copy) NSString *url;

// 跳过所有缓存，直接从服务器下载最新头像（打开详情页时调用）
-(void) refreshUrlFromServer:(NSString*)url;

@property(nonatomic,copy) NSString *uid;

@property(nonatomic,assign) CGFloat borderWidth;

@property(nonatomic,strong) WKImageView *avatarImgView;


@end

NS_ASSUME_NONNULL_END

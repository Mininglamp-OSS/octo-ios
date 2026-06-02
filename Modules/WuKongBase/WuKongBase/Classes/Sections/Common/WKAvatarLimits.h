//
//  WKAvatarLimits.h
//  WuKongBase
//
//  动图头像相关上限常量。
//  动图 (GIF / APNG / 动 WebP / 视频转 GIF) 不走 TOCropViewController，
//  最大 5 MB，超过的输入数据先经过压缩，仍超时拒绝上传。
//

#ifndef WKAvatarLimits_h
#define WKAvatarLimits_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/// 动图头像总字节上限 (5 MB)。
static const NSUInteger WK_AVATAR_ANIMATED_MAX_BYTES = 5 * 1024 * 1024;

/// 输入视频最少时长 (秒)。低于该时长直接拒绝。
static const NSTimeInterval WK_AVATAR_VIDEO_MIN_SEC = 3.0;

/// 输出 GIF 最长时长 (秒)。视频 ≤ 该值直接全转，> 该值进 trimmer 截取该长度窗口。
/// 命名注意：是 MAX 而非固定值——4 秒视频会输出 4 秒 GIF，不会被砍成 3 秒。
static const NSTimeInterval WK_AVATAR_VIDEO_OUTPUT_MAX_SEC = 5.0;

#endif /* WKAvatarLimits_h */

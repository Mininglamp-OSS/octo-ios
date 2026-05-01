//
//  WKGroupScanJoinVC.h
//  WuKongBase
//

#import "WKBaseVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKGroupScanJoinVC : WKBaseVC

@property(nonatomic,copy) NSString *groupNo;
@property(nonatomic,copy) NSString *authCode;
@property(nonatomic,copy) NSString *groupName;
@property(nonatomic,copy) NSString *groupAvatar;
@property(nonatomic,assign) NSInteger memberCount;
@property(nonatomic,assign) BOOL isMember; // 是否已在群内

// YUJ-141: 跨 Space 加群场景（从邀请链接 / 扫码解析出来的目标 Space）。
// - `targetSpaceId` 为空表示扫/链路层未识别出 Space，VC 会走旧路径（直接进群）。
// - `targetSpaceName` 展示用；与 `targetSpaceId` 配对，允许为空（dialog 里兜底为"其它"）。
@property(nonatomic,copy,nullable) NSString *targetSpaceId;
@property(nonatomic,copy,nullable) NSString *targetSpaceName;

@end

NS_ASSUME_NONNULL_END

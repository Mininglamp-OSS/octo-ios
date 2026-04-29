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

@end

NS_ASSUME_NONNULL_END

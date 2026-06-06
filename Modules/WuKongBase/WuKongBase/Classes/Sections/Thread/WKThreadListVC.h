//
//  WKThreadListVC.h
//  WuKongBase
//

#import "WKBaseVC.h"
#import "WKChannel.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKThreadListVC : WKBaseVC

@property (nonatomic, copy) NSString *groupNo;

/// 进入时默认选中的 segment：0=活跃（默认），1=已归档
@property (nonatomic, assign) NSInteger initialSegmentIndex;

@end

NS_ASSUME_NONNULL_END

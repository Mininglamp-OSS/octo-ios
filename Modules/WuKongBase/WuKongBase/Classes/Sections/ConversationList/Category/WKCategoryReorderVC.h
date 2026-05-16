//
//  WKCategoryReorderVC.h
//  WuKongBase
//
//  分组排序页面（拖拽排序 + 上移/下移/移到最前/移到最后）
//

#import "WKBaseVC.h"

@class WKCategoryEntity;

NS_ASSUME_NONNULL_BEGIN

@interface WKCategoryReorderVC : WKBaseVC

@property (nonatomic, copy) NSString *spaceId;
@property (nonatomic, strong) NSArray<WKCategoryEntity *> *categories;
@property (nonatomic, copy, nullable) void(^onReorderComplete)(void);

@end

NS_ASSUME_NONNULL_END

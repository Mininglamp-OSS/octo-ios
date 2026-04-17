//
//  WKCategoryEntity.h
//  WuKongBase
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKCategoryGroup : NSObject
@property (nonatomic, copy) NSString *group_no;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger category_sort;
+ (instancetype)fromDict:(NSDictionary *)dict;
@end

@interface WKCategoryEntity : NSObject
@property (nonatomic, copy) NSString *category_id;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger sort;
@property (nonatomic, assign) BOOL is_default;
@property (nonatomic, strong, nullable) NSArray<WKCategoryGroup *> *groups;
+ (instancetype)fromDict:(NSDictionary *)dict;
+ (NSArray<WKCategoryEntity *> *)fromDictArray:(NSArray *)array;
@end

NS_ASSUME_NONNULL_END

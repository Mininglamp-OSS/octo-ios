//
//  WKSpaceEntity.h
//  WuKongBase
//
//  Created by Claude on 2026/03/11.
//

#import <Foundation/Foundation.h>
#import "WKModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSpaceMember : WKModel

@property(nonatomic,copy) NSString *uid;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,assign) NSInteger role; // 0=member, 1=admin, 2=owner
@property(nonatomic,copy) NSString *created_at;

@end

@interface WKSpaceEntity : WKModel

@property(nonatomic,copy) NSString *space_id;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *desc;
@property(nonatomic,copy) NSString *owner_uid;
@property(nonatomic,assign) NSInteger member_count;
@property(nonatomic,copy) NSString *created_at;
@property(nonatomic,copy) NSString *updated_at;

@end

NS_ASSUME_NONNULL_END

//
//  WKSyncService.h
//  WuKongBase
//
//  Created by tt on 2019/12/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSyncService : NSObject

+ (instancetype)shared;

-(void) sync;

-(void) sync:(void(^__nullable)(NSError * __nullable error))callback;

// 同步联系人
-(void) syncContacts:(void (^)(NSError * __nullable error))callback;
@end

NS_ASSUME_NONNULL_END

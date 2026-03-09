//
//  WKChannelDataManager.h
//  25519
//
//  Created by tt on 2022/12/2.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

@class WKChannelDataManager;

NS_ASSUME_NONNULL_BEGIN

@protocol WKChannelDataManagerDelegate <NSObject>

-(void) channelDataManager:(WKChannelDataManager*)manager members:(WKChannel*)channel keyword:(NSString * __nullable )keyword page:(NSInteger)page limit:(NSInteger)limit complete:(void(^__nullable)(NSError * __nullable error,NSArray<WKChannelMember*>* __nullable members))complete;

@end

@interface WKChannelDataManager : NSObject

+ (WKChannelDataManager *)shared;

@property(nonatomic,strong) id<WKChannelDataManagerDelegate> delegate;

-(void) members:(WKChannel*)channel keyword:(NSString * __nullable )keyword page:(NSInteger)page limit:(NSInteger)limit complete:(void(^__nullable)(NSError * __nullable error,NSArray<WKChannelMember*>* __nullable members))complete;


@end

NS_ASSUME_NONNULL_END

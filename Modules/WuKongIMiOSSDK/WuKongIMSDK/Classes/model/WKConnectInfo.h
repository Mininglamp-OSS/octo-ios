//
//  WKConnectInfo.h
//  WuKongIMSDK
//
//  Created by tt on 2020/2/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKConnectInfo : NSObject

@property(nonatomic,copy) NSString *uid;
@property(nonatomic,copy) NSString *token;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *avatar;

+(instancetype) initWithUID:(NSString*)uid token:(NSString*)token name:(NSString*)name avatar:(NSString*)avatar;

@end

NS_ASSUME_NONNULL_END

//
//  WKURLSessionDataTask.h
//  WuKongBase
//
//  Created by tt on 2022/5/13.
//

#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKDowloadTask : WKBaseTask

@property(nonatomic,copy) NSString *url;
@property(nonatomic,copy) NSString *storePath;

-(instancetype) initWithURL:(NSString*)url storePath:(NSString*)storePath;

@end

NS_ASSUME_NONNULL_END

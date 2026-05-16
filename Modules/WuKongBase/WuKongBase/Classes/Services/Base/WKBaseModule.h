//
//  WKBaseModule.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import <Foundation/Foundation.h>
#import "WKModuleProtocol.h"
#import "WKEndpoint.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKBaseModule : NSObject<WKModuleProtocol>

+(NSString*) globalID;

-(void) setMethod:(NSString*)sid handler:(id) handler category:(NSString * __nullable)category;

-(void) setMethod:(NSString*)sid handler:(id) handler category:(NSString* __nullable)category sort:(int)sort;

-(void) setMethod:(NSString*)sid handler:(id) handler;

@end

NS_ASSUME_NONNULL_END

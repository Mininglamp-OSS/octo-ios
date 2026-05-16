//
//  WKSchemaManager.h
//  WuKongBase
//
//  Created by tt on 2022/4/29.
//

#import <Foundation/Foundation.h>
@class WKSchemaRequest;
NS_ASSUME_NONNULL_BEGIN

typedef BOOL(^WKSchemaHandler)(WKSchemaRequest *request);

@interface WKSchemaRequest : NSObject

@property(nonatomic,strong) NSURL *url;

+(WKSchemaRequest*) url:(NSURL*)url;

-(BOOL) isAppSchema;

-(NSDictionary<NSString*,NSString*>*)queryItems;

@end

@interface WKSchemaManager : NSObject

+ (instancetype)shared;

-(void) registerHandler:(NSString*)sid handler:(WKSchemaHandler)handler;

-(void) handle:(WKSchemaRequest*)request;

-(void) handleURL:(NSURL*)url;

@end

NS_ASSUME_NONNULL_END

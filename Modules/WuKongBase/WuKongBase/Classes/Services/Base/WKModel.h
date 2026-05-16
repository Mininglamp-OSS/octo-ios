//
//  ATModel.h
//  Login
//
//  Created by tt on 2018/9/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    ModelMapTypeAPI,
    ModelMapTypeDB,
} ModelMapType;

@interface WKModel : NSObject

+(WKModel* _Nonnull) fromMap:(NSDictionary*)dictory type:(ModelMapType)type;

-(NSDictionary* _Nonnull) toMap:(ModelMapType)type;
@end

NS_ASSUME_NONNULL_END

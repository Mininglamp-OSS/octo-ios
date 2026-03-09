//
//  WKContactsFriendDB.h
//  WuKongContacts
//
//  Created by tt on 2021/9/22.
//

#import <Foundation/Foundation.h>
#import <WuKongBase/WuKongBase.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKContactsFriendDBModel : NSObject

@property(nonatomic,strong) NSString *name;
@property(nonatomic,strong) NSString *phone;

@end

@interface WKContactsFriendDB : NSObject

+ (instancetype)shared;

-(void) save:(NSArray<WKContactsFriendDBModel*>*) models;

-(NSArray<WKContactsFriendDBModel*>*) queryAll;

@end

NS_ASSUME_NONNULL_END

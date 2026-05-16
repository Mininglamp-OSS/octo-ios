//
//  WKSensitivewordsService.h
//  WuKongBase
//
//  Created by tt on 2024/4/29.
//

#import <Foundation/Foundation.h>
#import "WKSync.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKProhibitwordsService : NSObject<WKSync>

+ (instancetype)shared;

@property(nonatomic,strong) NSMutableArray<NSDictionary*> *prohibitwords;

- (NSString *)filter:(NSString *)message;

@end

NS_ASSUME_NONNULL_END

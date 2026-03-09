//
//  WKRNNoise.h
//  WuKongBase
//
//  Created by tt on 2023/2/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKRNNoise : NSObject

+ (WKRNNoise *)shared;

-(NSError*) rnnoiseProcess:(NSString*)srcFilepath saveFilePath:(NSString*)saveFilePath;

@end

NS_ASSUME_NONNULL_END

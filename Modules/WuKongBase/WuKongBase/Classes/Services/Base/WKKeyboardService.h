//
//  WKKeyboardService.h
//  WuKongBase
//
//  Created by tt on 2022/9/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKKeyboardService : NSObject

+ (WKKeyboardService *)shared;

@property(nonatomic,assign) BOOL keyboardIsVisible;

-(void) setup;

@end

NS_ASSUME_NONNULL_END

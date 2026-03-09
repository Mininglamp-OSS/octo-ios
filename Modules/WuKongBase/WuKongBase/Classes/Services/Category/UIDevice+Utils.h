//
//  UIDevice+Utils.h
//  WuKongBase
//
//  Created by tt on 2020/10/22.
//

#import <UIKit/UIKit.h>
#import <sys/utsname.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (Utils)

+ (NSString*)getUUID;
+ (NSString*)getDeviceModel;
+ (NSString*)getDeviceName;

@end

NS_ASSUME_NONNULL_END

//
//  UIDevice+Utils.m
//  WuKongBase
//
//  Created by tt on 2020/10/22.
//


#import "UIDevice+Utils.h"
#import "WKKeychainUtil.h"



@implementation UIDevice (Utils)

+ (NSString *)getUUID
{
    NSString * bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSString * tmpID = [NSString stringWithFormat:@"%@_UUID",bundleId];
    NSData * tmpData = [WKKeychainUtil searchKeychainCopyMatchingIdentifier:tmpID];
    if (!tmpData)
    {
        NSString * uuid = [UIDevice currentDevice].identifierForVendor.UUIDString;
        [WKKeychainUtil createKeychainValue:uuid
                                         forIdentifier:tmpID];
        return uuid;
        
    } else
    {
        return [[NSString alloc] initWithData:tmpData
                                     encoding:NSUTF8StringEncoding];
    }
}

+ (NSString *)getDeviceModel
{
    return [self platformString];
}
+ (NSString *)getDeviceName
{
    return [[UIDevice currentDevice] name];
}


+ (NSString *)platformString
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString * platform = [NSString stringWithCString:systemInfo.machine
                                             encoding:NSUTF8StringEncoding];
    
    if ([platform rangeOfString:@"iPhone"].location != NSNotFound)
    {
        return [self iPhonePlatform:platform];
    }
    if ([platform rangeOfString:@"iPad"].location != NSNotFound)
    {
        return [self iPadPlatform:platform];
    }
    if ([platform rangeOfString:@"iPod"].location != NSNotFound)
    {
        return [self iPodPlatform:platform];
    }
    if ([platform isEqualToString:@"i386"] || [platform isEqualToString:@"x86_64"])
    {
        return @"Simulator"; //模拟器
    }
    
    return @"Unknown iOS Device";
}

//iPhone设备
+ (NSString *)iPhonePlatform:(NSString *)platform
{
    if ([platform isEqualToString:@"iPhone1,1"])    return @"iPhone 2G";
    if ([platform isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([platform isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,2"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,3"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone5,1"])    return @"iPhone 5";
    if ([platform isEqualToString:@"iPhone5,2"])    return @"iPhone 5";
    if ([platform isEqualToString:@"iPhone5,3"])    return @"iPhone 5c";
    if ([platform isEqualToString:@"iPhone5,4"])    return @"iPhone 5c";
    if ([platform isEqualToString:@"iPhone6,1"])    return @"iPhone 5s";
    if ([platform isEqualToString:@"iPhone6,2"])    return @"iPhone 5s";
    if ([platform isEqualToString:@"iPhone7,2"])    return @"iPhone 6";
    if ([platform isEqualToString:@"iPhone7,1"])    return @"iPhone 6 Plus";
    if ([platform isEqualToString:@"iPhone8,1"])    return @"iPhone 6s";
    if ([platform isEqualToString:@"iPhone8,2"])    return @"iPhone 6s Plus";
    if ([platform isEqualToString:@"iPhone8,4"])    return @"iPhone SE";
    if ([platform isEqualToString:@"iPhone9,1"])    return @"iPhone 7";
    if ([platform isEqualToString:@"iPhone9,3"])    return @"iPhone 7";
    if ([platform isEqualToString:@"iPhone9,2"])    return @"iPhone 7 Plus";
    if ([platform isEqualToString:@"iPhone9,4"])    return @"iPhone 7 Plus";
    // 2017年9月发布，更新三种机型：iPhone 8、iPhone 8 Plus、iPhone X
    if ([platform isEqualToString:@"iPhone10,1"])   return @"iPhone 8";
    if ([platform isEqualToString:@"iPhone10,4"])   return @"iPhone 8";
    if ([platform isEqualToString:@"iPhone10,2"])   return @"iPhone 8 Plus";
    if ([platform isEqualToString:@"iPhone10,5"])   return @"iPhone 8 Plus";
    if ([platform isEqualToString:@"iPhone10,3"])   return @"iPhone X";
    if ([platform isEqualToString:@"iPhone10,6"])   return @"iPhone X";
    // 2018年10月发布，更新三种机型：iPhone XR、iPhone XS、iPhone XS Max
    if ([platform isEqualToString:@"iPhone11,8"])   return @"iPhone XR";
    if ([platform isEqualToString:@"iPhone11,2"])   return @"iPhone XS";
    if ([platform isEqualToString:@"iPhone11,4"])   return @"iPhone XS Max";
    if ([platform isEqualToString:@"iPhone11,6"])   return @"iPhone XS Max";
    // 2019年9月发布，更新三种机型：iPhone 11、iPhone 11 Pro、iPhone 11 Pro Max
    if ([platform isEqualToString:@"iPhone12,1"])   return  @"iPhone 11";
    if ([platform isEqualToString:@"iPhone12,3"])   return  @"iPhone 11 Pro";
    if ([platform isEqualToString:@"iPhone12,5"])   return  @"iPhone 11 Pro Max";
    if ([platform isEqualToString:@"iPhone12,8"])   return  @"iPhone SE (2 Gen)";
    
    // 2020年10月发布，更新三种机型：iPhone 12 mini、Phone 12、iPhone 12 Pro， iPhone 12 Pro Max
    if ([platform isEqualToString:@"iPhone13,1"])   return  @"iPhone 12 mini";
    if ([platform isEqualToString:@"iPhone13,2"])   return  @"iPhone 12";
    if ([platform isEqualToString:@"iPhone13,3"])   return  @"iPhone 12 Pro";
    if ([platform isEqualToString:@"iPhone13,4"])   return  @"iPhone 12 Pro Max";
    
    return @"Unknown iPhone";
}

//iPad设备
+ (NSString *)iPadPlatform:(NSString *)platform
{
    if ([platform isEqualToString:@"iPad1,1"])  return @"iPad";
    if ([platform isEqualToString:@"iPad1,2"])  return @"iPad 3G";
    if ([platform isEqualToString:@"iPad2,1"])  return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,2"])  return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,3"])  return @"iPad 2 (CDMA)";
    if ([platform isEqualToString:@"iPad2,4"])  return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,5"])  return @"iPad Mini (WiFi)";
    if ([platform isEqualToString:@"iPad2,6"])  return @"iPad Mini";
    if ([platform isEqualToString:@"iPad2,7"])  return @"iPad Mini (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,1"])  return @"iPad 3 (WiFi)";
    if ([platform isEqualToString:@"iPad3,2"])  return @"iPad 3 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,3"])  return @"iPad 3";
    if ([platform isEqualToString:@"iPad3,4"])  return @"iPad 4 (WiFi)";
    if ([platform isEqualToString:@"iPad3,5"])  return @"iPad 4";
    if ([platform isEqualToString:@"iPad3,6"])  return @"iPad 4 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad4,1"])  return @"iPad Air (WiFi)";
    if ([platform isEqualToString:@"iPad4,2"])  return @"iPad Air (Cellular)";
    if ([platform isEqualToString:@"iPad4,4"])  return @"iPad Mini 2 (WiFi)";
    if ([platform isEqualToString:@"iPad4,5"])  return @"iPad Mini 2 (Cellular)";
    if ([platform isEqualToString:@"iPad4,6"])  return @"iPad Mini 2";
    if ([platform isEqualToString:@"iPad4,7"])  return @"iPad Mini 3";
    if ([platform isEqualToString:@"iPad4,8"])  return @"iPad Mini 3";
    if ([platform isEqualToString:@"iPad4,9"])  return @"iPad Mini 3";
    if ([platform isEqualToString:@"iPad5,1"])  return @"iPad Mini 4 (WiFi)";
    if ([platform isEqualToString:@"iPad5,2"])  return @"iPad Mini 4 (LTE)";
    if ([platform isEqualToString:@"iPad5,3"])  return @"iPad Air 2";
    if ([platform isEqualToString:@"iPad5,4"])  return @"iPad Air 2";
    if ([platform isEqualToString:@"iPad6,3"])  return @"iPad Pro 9.7";
    if ([platform isEqualToString:@"iPad6,4"])  return @"iPad Pro 9.7";
    if ([platform isEqualToString:@"iPad6,7"])  return @"iPad Pro 12.9";
    if ([platform isEqualToString:@"iPad6,8"])  return @"iPad Pro 12.9";
    if ([platform isEqualToString:@"iPad6,11"]) return @"iPad 5 (WiFi)";
    if ([platform isEqualToString:@"iPad6,12"]) return @"iPad 5 (Cellular)";
    if ([platform isEqualToString:@"iPad7,1"])  return @"iPad Pro 12.9 inch 2nd gen (WiFi)";
    if ([platform isEqualToString:@"iPad7,2"])  return @"iPad Pro 12.9 inch 2nd gen (Cellular)";
    if ([platform isEqualToString:@"iPad7,3"])  return @"iPad Pro 10.5 inch (WiFi)";
    if ([platform isEqualToString:@"iPad7,4"])  return @"iPad Pro 10.5 inch (Cellular)";
    // 2019年3月发布，更新二种机型：iPad mini、iPad Air
    if ([platform isEqualToString:@"iPad11,1"]) return @"iPad mini (5th generation)";
    if ([platform isEqualToString:@"iPad11,2"]) return @"iPad mini (5th generation)";
    if ([platform isEqualToString:@"iPad11,3"]) return @"iPad Air (3rd generation)";
    if ([platform isEqualToString:@"iPad11,4"]) return @"iPad Air (3rd generation)";
    
    return @"Unknown iPad";
}

//iPod设备
+ (NSString *)iPodPlatform:(NSString *)platform
{
    if ([platform isEqualToString:@"iPod1,1"])  return @"iPod Touch 1G";
    if ([platform isEqualToString:@"iPod2,1"])  return @"iPod Touch 2G";
    if ([platform isEqualToString:@"iPod3,1"])  return @"iPod Touch 3G";
    if ([platform isEqualToString:@"iPod4,1"])  return @"iPod Touch 4G";
    if ([platform isEqualToString:@"iPod5,1"])  return @"iPod Touch (5 Gen)";
    if ([platform isEqualToString:@"iPod7,1"])  return @"iPod Touch (6th generation)";
    // 2019年5月发布，更新一种机型：iPod touch (7th generation)
    if ([platform isEqualToString:@"iPod9,1"])  return @"iPod Touch (7th generation)";

    return @"Unknown iPod";
}


@end

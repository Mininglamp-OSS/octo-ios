//
//  WKKeychainUtil.m
//  WuKongBase
//
//  Created by tt on 2020/10/22.
//

#import "WKKeychainUtil.h"

@implementation WKKeychainUtil


+ (NSMutableDictionary*)newSearchDictionary:(NSString*)identifier
{
    NSMutableDictionary* searchDictionary = [NSMutableDictionary dictionary];
    //指定item的类型为GenericPassword
    [searchDictionary setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];

    //类型为GenericPassword的信息必须提供以下两条属性作为unique identifier
    [searchDictionary setObject:identifier forKey:(id)kSecAttrAccount];
    [searchDictionary setObject:identifier forKey:(id)kSecAttrService];

    return searchDictionary;
}
+ (NSData*)searchKeychainCopyMatchingIdentifier:(NSString*)identifier
{
    NSMutableDictionary* searchDictionary = [self newSearchDictionary:identifier];

    //在搜索keychain item的时候必须提供下面的两条用于搜索的属性
    //只返回搜索到的第一条item，这个是搜索条件。
    [searchDictionary setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
    //返回item的kSecValueData 字段。也就是我们一般用于存放的密码，返回类型为NSData *类型
    [searchDictionary setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];

    //我来解释下这里匹配出的是 找到一条符合ksecAttrAccount、类型为普通密码类型kSecClass，返回ksecValueData字段。
    NSData* result = nil;
    CFDataRef keyData = NULL;
    if (SecItemCopyMatching((CFDictionaryRef)searchDictionary, (CFTypeRef*)&keyData) == errSecSuccess) {
        @try {
            result = (__bridge NSData*)keyData;
        } @catch (NSException* e) {
            NSLog(@"Unarchive of %@ failed: %@", identifier, e);
        } @finally {
        }
    }
    if (keyData)
        CFRelease(keyData);

    return result;
}
+ (BOOL)createKeychainValue:(NSString*)password forIdentifier:(NSString*)identifier
{
    NSMutableDictionary* dictionary = [self newSearchDictionary:identifier];

    //非常值得注意的事kSecValueData字段只接受UTF8格式的 NSData *类型，否则addItem/updateItem就会crash，并且一定记得带上service和account字段
    NSData* passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    [dictionary setObject:passwordData forKey:(id)kSecValueData];

    OSStatus status = SecItemAdd((CFDictionaryRef)dictionary, NULL);

    if (status == errSecSuccess) {
        return YES;
    }
    return NO;
}
+ (BOOL)updateKeychainValue:(NSString*)password forIdentifier:(NSString*)identifier
{
    NSMutableDictionary* searchDictionary = [self newSearchDictionary:identifier];

    NSMutableDictionary* updateDictionary = [NSMutableDictionary dictionary];
    NSData* passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    [updateDictionary setObject:passwordData forKey:(id)kSecValueData];

    //这里也有需要注意的地方，searchDictionary为搜索条件，updateDictionary为需要更新的字典。这两个字典中一定不能有相同的key，否则就会更新失败
    OSStatus status = SecItemUpdate((CFDictionaryRef)searchDictionary,
        (CFDictionaryRef)updateDictionary);

    if (status == errSecSuccess) {
        return YES;
    }
    return NO;
}
+ (void)deleteKeychainValueForIdentifier:(NSString*)identifier
{
    NSMutableDictionary* searchDictionary = [self newSearchDictionary:identifier];
    SecItemDelete((CFDictionaryRef)searchDictionary);
}


@end

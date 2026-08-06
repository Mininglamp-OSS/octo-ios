//
//  WKSpaceDiskCache.m
//  WuKongBase
//

#import "WKSpaceDiskCache.h"
#import "WKLoginInfo.h"

@implementation WKSpaceDiskCache

+ (dispatch_queue_t)ioQueue {
    static dispatch_queue_t q;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        q = dispatch_queue_create("com.octo.spaceDiskCache", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

+ (nullable NSString *)userDirectoryCreateIfNeeded:(BOOL)create {
    NSString *uid = [WKLoginInfo shared].uid;
    if (uid.length == 0) return nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    if (paths.count == 0) return nil;
    NSString *dir = [[paths.firstObject stringByAppendingPathComponent:@"octo/spaceCache"]
                     stringByAppendingPathComponent:uid];
    if (create && ![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&error];
        if (error) {
            NSLog(@"[SpaceDiskCache] 创建目录失败: %@", error);
            return nil;
        }
    }
    return dir;
}

/// spaceId 可能带路径不安全字符，做一次白名单化。
+ (NSString *)sanitize:(NSString *)raw {
    NSMutableString *out = [NSMutableString stringWithCapacity:raw.length];
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        BOOL ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
                  || c == '-' || c == '_';
        [out appendFormat:@"%C", ok ? c : (unichar)'_'];
    }
    return out;
}

+ (nullable NSString *)filePathForNamespace:(NSString *)ns spaceId:(NSString *)spaceId create:(BOOL)create {
    if (ns.length == 0 || spaceId.length == 0) return nil;
    NSString *dir = [self userDirectoryCreateIfNeeded:create];
    if (!dir) return nil;
    NSString *name = [NSString stringWithFormat:@"%@_%@.json", [self sanitize:ns], [self sanitize:spaceId]];
    return [dir stringByAppendingPathComponent:name];
}

+ (nullable id)objectForNamespace:(NSString *)ns spaceId:(NSString *)spaceId {
    NSString *path = [self filePathForNamespace:ns spaceId:spaceId create:NO];
    if (!path) return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) return nil;
    NSError *error = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSLog(@"[SpaceDiskCache] 解析失败 ns=%@ space=%@: %@", ns, spaceId, error);
        return nil;
    }
    return obj;
}

+ (void)setObject:(nullable id)obj forNamespace:(NSString *)ns spaceId:(NSString *)spaceId {
    if (!obj) {
        [self removeNamespace:ns spaceId:spaceId];
        return;
    }
    if (![NSJSONSerialization isValidJSONObject:obj]) {
        NSLog(@"[SpaceDiskCache] 对象不可 JSON 序列化，跳过 ns=%@", ns);
        return;
    }
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:&error];
    if (!data) {
        NSLog(@"[SpaceDiskCache] 序列化失败 ns=%@: %@", ns, error);
        return;
    }
    NSString *nsCopy = [ns copy], *spaceCopy = [spaceId copy];
    dispatch_async([self ioQueue], ^{
        NSString *path = [self filePathForNamespace:nsCopy spaceId:spaceCopy create:YES];
        if (!path) return;
        // 原子写：中途被杀不会留下半个文件（回读时 JSON 解析失败会被当成无缓存）
        NSError *writeError = nil;
        if (![data writeToFile:path options:NSDataWritingAtomic error:&writeError]) {
            NSLog(@"[SpaceDiskCache] 写入失败 ns=%@ space=%@: %@", nsCopy, spaceCopy, writeError);
        }
    });
}

+ (void)removeNamespace:(NSString *)ns spaceId:(NSString *)spaceId {
    NSString *nsCopy = [ns copy], *spaceCopy = [spaceId copy];
    dispatch_async([self ioQueue], ^{
        NSString *path = [self filePathForNamespace:nsCopy spaceId:spaceCopy create:NO];
        if (!path) return;
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    });
}

+ (void)removeAllForCurrentUser {
    NSString *dir = [self userDirectoryCreateIfNeeded:NO];
    if (!dir) return;
    dispatch_async([self ioQueue], ^{
        [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
    });
}

@end

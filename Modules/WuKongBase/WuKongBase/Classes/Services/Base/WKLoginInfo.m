//
//  WKLoginInfo.m
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import "WKLoginInfo.h"
#define uidKey @"uid"
#define tokenKey @"token"
#define imTokenKey @"imtoken"
#define deviceTokenKey @"deviceToken"
#define extraKey @"extra"
#define LoginInfoKey @"WKLoginInfo"



@interface WKLoginInfo ()


@end

@implementation WKLoginInfo


static WKLoginInfo *_instance;


//+ (id)allocWithZone:(NSZone *)zone
//{
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        _instance = [super allocWithZone:zone];
//    });
//    return _instance;
//}
+ (WKLoginInfo *)shared
{
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        _instance = [[self alloc] init];
//        NSLog(@"---%@",[_instance class]);
//
//    });
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}
- (void)encodeWithCoder:(nonnull NSCoder *)encoder {
    if(self.uid){
        [encoder encodeObject:self.uid forKey:uidKey];
    }
    if(self.token) {
        [encoder encodeObject:self.token forKey:tokenKey];
    }
    if(self.imToken) {
        [encoder encodeObject:self.imToken forKey:imTokenKey];
    }
    if(self.deviceToken) {
        [encoder encodeObject:self.deviceToken forKey:deviceTokenKey];
    }
    if(self.extra) {
        [encoder encodeObject:self.extra forKey:extraKey];
    }else {
        [encoder encodeObject:@{} forKey:extraKey];
    }
    
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder {
    self.uid = [decoder decodeObjectForKey:uidKey];
    self.token = [decoder decodeObjectForKey:tokenKey];
    self.imToken = [decoder decodeObjectForKey:imTokenKey];
    self.deviceToken = [decoder decodeObjectForKey:deviceTokenKey];
    self.extra = [decoder decodeObjectForKey:extraKey];
    return self;
}

-(NSMutableDictionary*) extra {
    if(!_extra) {
        _extra = [[NSMutableDictionary alloc] init];
    }
    return _extra;
}


-(id) extraValueForKey:(NSString*)key{
    if(self.extra) {
        return self.extra[key];
    }
    return nil;
}

-(void) setExtraValue:(id) value forKey:(NSString*)key{
    if(!self.extra) {
        self.extra = [[NSMutableDictionary alloc] init];
    }
    [self.extra setObject:value forKey:key];
}


#pragma mark - 实名认证（realname verification）

// extra 字段键名（与后端 /v1/internal/verification/complete 以及 channelInfo.extra 对齐）
static NSString *const kRealnameVerifiedKey   = @"realname_verified";
static NSString *const kRealNameKey           = @"real_name";
static NSString *const kRealnameVerifiedAtKey = @"realname_verified_at";

- (BOOL)realnameVerified {
    id v = self.extra[kRealnameVerifiedKey];
    return v ? [v boolValue] : NO;
}

- (void)setRealnameVerified:(BOOL)realnameVerified {
    if(!self.extra) {
        self.extra = [[NSMutableDictionary alloc] init];
    }
    self.extra[kRealnameVerifiedKey] = @(realnameVerified);
}

- (NSString *)realName {
    id v = self.extra[kRealNameKey];
    if([v isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)v;
        return s.length > 0 ? s : nil;
    }
    return nil;
}

- (void)setRealName:(NSString *)realName {
    if(!self.extra) {
        self.extra = [[NSMutableDictionary alloc] init];
    }
    if(realName) {
        self.extra[kRealNameKey] = [realName copy];
    } else {
        [self.extra removeObjectForKey:kRealNameKey];
    }
}

- (NSTimeInterval)realnameVerifiedAt {
    id v = self.extra[kRealnameVerifiedAtKey];
    return v ? [v doubleValue] : 0;
}

- (void)setRealnameVerifiedAt:(NSTimeInterval)ts {
    if(!self.extra) {
        self.extra = [[NSMutableDictionary alloc] init];
    }
    self.extra[kRealnameVerifiedAtKey] = @(ts);
}

- (NSString *)displayName {
    // 已实名 && 真实姓名非空 → 展示真实姓名；否则回落到昵称
    NSString *rn = self.realName;
    if(self.realnameVerified && rn.length > 0) {
        return rn;
    }
    id n = self.extra[@"name"];
    if([n isKindOfClass:[NSString class]]) {
        return (NSString *)n;
    }
    return @"";
}



- (NSString *)deviceUUID {
    if(!_deviceUUID) {
        if(self.uid && ![self.uid isEqualToString:@""]) {
            NSString *key = [NSString stringWithFormat:@"deviceUUID:%@",self.uid];
            NSString *deviceUUID = [[NSUserDefaults standardUserDefaults] objectForKey:key];
            if(deviceUUID) {
                _deviceUUID = deviceUUID;
            }else {
                NSString *uuid = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
                [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:key];
                [[NSUserDefaults standardUserDefaults]  synchronize];
                _deviceUUID = uuid;
            }
        }
       
    }
    return _deviceUUID;
}

-(void) load{
    _instance =  [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:LoginInfoKey]];
    if(!_instance) {
        _instance = [[WKLoginInfo alloc]init];
    }
}


-(void) save{
    NSUserDefaults  *userDefaults =[NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:self] forKey:LoginInfoKey];
    [userDefaults synchronize];
}

-(void) clear{
    self.token = @"";
    self.uid = @"";
    self.imToken = @"";
    self.extra = [[NSMutableDictionary alloc] init];
    NSUserDefaults  *userDefaults =[NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:LoginInfoKey];
    [userDefaults synchronize];
}

-(void) clearMainData {
    self.token = @"";
    self.imToken = @"";
    // 仅保留区号和手机号 其他都清除
    NSString *zone = self.extra[@"zone"];
    NSString *phone = self.extra[@"phone"];
    NSString *style = self.extra[@"systemStyle"];
    NSString *darkModeWithSystem = self.extra[@"darkModeWithSystem"];
    [self.extra removeAllObjects];
    
    self.extra[@"zone"] = zone?:@"";
    self.extra[@"phone"] = phone?:@"";
    self.extra[@"systemStyle"] = style?:@"";
    self.extra[@"darkModeWithSystem"] = darkModeWithSystem?:@"";
    
    [self save];
}
@end

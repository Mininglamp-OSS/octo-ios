//
//  WKSensitivewordsService.m
//  WuKongBase
//
//  Created by tt on 2024/4/29.
//

#import "WKProhibitwordsService.h"
#import "WKAPIClient.h"
#import "WKJsonUtil.h"

@interface WKProhibitwordsService()

@property (nonatomic,strong) NSMutableDictionary *keywordChains;
@property (nonatomic,copy) NSString *delimit;

@end

@implementation WKProhibitwordsService


static WKProhibitwordsService *_instance = nil;
+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone ];
       
    });
    return _instance;
}

+(instancetype) shared{
    if (_instance == nil) {
        _instance = [[super alloc]init];
        _instance.delimit = @"\x00";
    }
    return _instance;
}

- (BOOL)needSync {
    return true;
}

- (void)sync:(void (^)(NSError *))callback {
    callback(nil); // 直接返回，因为成功与否 都不影响程序的逻辑
    [self load]; //  加载敏感词
    NSInteger lastVersion = 0;
    if(self.prohibitwords && self.prohibitwords.count>0) {
       NSDictionary *lastDict = self.prohibitwords[self.prohibitwords.count-1];
        if(lastDict[@"version"]) {
            lastVersion = [lastDict[@"version"] integerValue];
        }
        [self refresh];
    }
    
    __weak typeof(self) weakSelf = self;
    [WKAPIClient.sharedClient GET:@"message/prohibit_words/sync" parameters:@{@"version":@(lastVersion)}].then(^(NSArray<NSDictionary*> *results){
        if(results && results.count>0) {
            NSInteger version = 0;
            for (NSDictionary *result in results) {
                if(result[@"version"]) {
                    version = [result[@"version"] integerValue];
                }
                if(version>lastVersion) {
                    [weakSelf.prohibitwords addObject:result];
                }
            }
            [weakSelf save];
            [weakSelf refresh];
        }
       
    });
}

-(void) refresh {
        [self.keywordChains removeAllObjects];
        BOOL isDeleted = false;
        for (NSDictionary *resultDict in self.prohibitwords) {
            if(resultDict[@"is_deleted"]) {
                isDeleted = [resultDict[@"is_deleted"] boolValue];
            }
            if(!isDeleted) {
                NSString *word = resultDict[@"content"];
                if(word && ![word isEqualToString:@""]) {
                    [self addProhibitword:word];
                }
            }
        }
}

- (void)addProhibitword:(NSString *)keyword{
    keyword = keyword.lowercaseString;
    keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSMutableDictionary *node = self.keywordChains;
    for (int i = 0; i < keyword.length; i ++) {
        NSString *word = [keyword substringWithRange:NSMakeRange(i, 1)];
        if (node[word] == nil) {
            node[word] = [NSMutableDictionary dictionary];
        }
        node = node[word];
    }
    //敏感词最后一个字符标识
    [node setValue:@0 forKey:self.delimit];
}
                  
- (NSString *)filter:(NSString *)message {
    return [self filter:message replaceKey:nil];
}
                  
- (NSString *)filter:(NSString *)message replaceKey:(NSString *)replaceKey{
    replaceKey = replaceKey == nil ? @"*" : replaceKey;
//   NSString  *message = msg.lowercaseString;
    NSMutableArray *retArray = [[NSMutableArray alloc] init];
    NSInteger start = 0;
    while (start < message.length) {
        NSMutableDictionary *level = self.keywordChains.mutableCopy;
        NSInteger step_ins = 0;
        NSString *message_chars = [message substringWithRange:NSMakeRange(start, message.length - start)];
        for(int i = 0; i < message_chars.length; i++){
            NSString *chars_i = [message_chars substringWithRange:NSMakeRange(i, 1)];
            if([level.allKeys containsObject:chars_i]){
                step_ins += 1;
                NSDictionary *level_char_dict = level[chars_i];
                if(![level_char_dict.allKeys containsObject:self.delimit]){
                    level = level_char_dict.mutableCopy;
                }else{
                    NSMutableString *ret_str = [[NSMutableString alloc] init];
                    for(int i = 0; i < step_ins; i++){
                        [ret_str appendString:replaceKey];
                    }
                    [retArray addObject:ret_str];
                    start += (step_ins - 1);
                    break;
                }
            }else{
                [retArray addObject:[NSString stringWithFormat:@"%C",[message characterAtIndex:start]]];
                break;
            }
        }
        start ++;
    }
    return [retArray componentsJoinedByString:@""];
}

- (NSMutableDictionary *)keywordChains{
    if(_keywordChains == nil){
        _keywordChains = [[NSMutableDictionary alloc] initWithDictionary:@{}];
    }
    return _keywordChains;
}


-(NSString*) savePath {
    NSString *filePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/prohibitwords.json"];
    return filePath;
}

-(void) load {
    NSString *filePath = [self savePath];
    NSMutableArray *prohibitwords = [NSMutableArray array];
    NSString *prohibitwordsJsonStr = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    if(prohibitwordsJsonStr && ![prohibitwordsJsonStr isEqualToString:@""]) {
        NSArray *items = [WKJsonUtil toArray:prohibitwordsJsonStr];
        prohibitwords = [NSMutableArray arrayWithArray:items];
    }
    self.prohibitwords = prohibitwords;
}

-(void) save {
    NSString *filePath = [self savePath];
    NSString *jsonStr = [WKJsonUtil toJson:self.prohibitwords];
    [jsonStr writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)title {
    return nil;
}
@end

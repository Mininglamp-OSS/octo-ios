// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKEmoticonService.m
//  WuKongBase
//
//  Created by tt on 2020/1/10.
//

#import "WKEmoticonService.h"
#import "WKApp.h"
#define kFaceIDKey          @"face_id"
#define kFaceNameKey        @"face_name"
#define kFaceImageNameKey   @"face_image_name"

#define kFaceRankKey        @"face_rank"
#define kFaceClickKey       @"face_click"

#define recentNum 7 // 最近表情最大数量

@implementation WKEmotion

@synthesize faceId;
@synthesize faceImageName;
@synthesize faceName;
@synthesize faceRank;

@end


@interface WKEmoticonService()

@property (strong, nonatomic) NSMutableArray *emojiFaceArrays;
@property (strong, nonatomic) NSMutableArray *recentFaceArrays;
@property (nonatomic,strong)    NSCache *tokens;

@property(nonatomic,copy) NSString *emojiReg;

@end


@implementation WKEmoticonService

static WKEmoticonService *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKEmoticonService *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        
    });
    return _instance;
}

- (instancetype)init{
    if (self = [super init]) {
        _tokens = [[NSCache alloc] init];
        _emojiFaceArrays = [NSMutableArray array];
        
        NSArray *faceArray = [NSArray arrayWithContentsOfFile:[self defaultEmojiFacePath]];
        NSDictionary *faceDic = faceArray[0];
        NSMutableArray *faceNames = [NSMutableArray array];
        [faceDic[@"data"] enumerateObjectsUsingBlock:^(NSDictionary* dic, NSUInteger idx, BOOL * _Nonnull stop) {
            WKEmotion *emotion = [WKEmotion new];
            emotion.faceId = dic[@"id"];
            emotion.faceName = dic[@"tag"];
            emotion.faceImageName = dic[@"file"];
            
            [self->_emojiFaceArrays addObject:emotion];
            
            [faceNames addObject:emotion.faceName];
        }];
        
        // 转义特殊字符（如 [ ] 用于自定义表情 [崇尚行动]）
        NSMutableArray *escapedNames = [NSMutableArray array];
        for (NSString *name in faceNames) {
            NSString *escaped = [name stringByReplacingOccurrencesOfString:@"[" withString:@"\\["];
            escaped = [escaped stringByReplacingOccurrencesOfString:@"]" withString:@"\\]"];
            [escapedNames addObject:escaped];
        }
        self.emojiReg = [NSString stringWithFormat:@"(%@)",[escapedNames componentsJoinedByString:@"|"]];
        NSLog(@"[Emoji] emojiReg first 200 chars: %@", [self.emojiReg substringToIndex:MIN(self.emojiReg.length, 200)]);
        NSLog(@"[Emoji] total emoji count: %lu", (unsigned long)faceNames.count);
        
        NSArray *recentArrays = [[NSUserDefaults standardUserDefaults] arrayForKey:@"recentFaceArrays"];
        if (recentArrays) {
            _recentFaceArrays = [NSMutableArray arrayWithArray:recentArrays];
        }else{
            _recentFaceArrays = [NSMutableArray array];
        }
    }
    return self;
}

+(instancetype) sharedInstance{
    static dispatch_once_t onceToken;
    static id shareInstance;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
    });
    return shareInstance;
}

- (NSString *)defaultEmojiFacePath{
    NSBundle *b= [WKApp.shared resourceBundle:@"WuKongBase"];
    return [b pathForResource:@"emoji" ofType:@"plist" inDirectory:@"emoji"];
}

-(NSArray<id<WKMatchToken>>*)parseEmotion:(NSString *)text{
    
    NSMutableArray<id<WKMatchToken>> *tokens = [_tokens objectForKey:text];
    if(tokens) {
        return tokens;
    }
    
    tokens = [NSMutableArray array];
    // 日志：检查是否能匹配自定义表情
    if ([text containsString:@"["] && [text containsString:@"]"]) {
        NSLog(@"[Emoji] parseEmotion called with bracket text: %@", [text substringToIndex:MIN(text.length, 50)]);
    }
    static NSRegularExpression *exp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[Emoji] creating regex with pattern length: %lu", (unsigned long)self.emojiReg.length);
        NSError *regexError = nil;
        exp = [NSRegularExpression regularExpressionWithPattern:self.emojiReg
                                                        options:NSRegularExpressionCaseInsensitive
                                                          error:&regexError];
        if (regexError) {
            NSLog(@"[Emoji] ERROR creating regex: %@", regexError);
        } else {
            NSLog(@"[Emoji] regex created OK");
        }
    });
    
    __block NSInteger index = 0;
    if ([text containsString:@"["] && [text containsString:@"]"]) {
        NSInteger matchCount = [exp numberOfMatchesInString:text options:0 range:NSMakeRange(0, text.length)];
        NSLog(@"[Emoji] regex match count for '%@': %ld, exp=%@", [text substringToIndex:MIN(text.length, 30)], (long)matchCount, exp ? @"OK" : @"NIL");
    }
    [exp enumerateMatchesInString:text
                          options:0
                            range:NSMakeRange(0, [text length])
                       usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                           NSString *rangeText = [text substringWithRange:result.range];
                           for (WKEmotion *emotion in self->_emojiFaceArrays) {
                               if ([emotion.faceName  isEqualToString:rangeText]) {
                                   if (result.range.location > index){
                                       NSRange rawRange = NSMakeRange(index, result.range.location - index);
                                       NSString *rawText = [text substringWithRange:rawRange];
                                       [tokens addObject: [WKDefaultToken text:rawText range:rawRange type:WKatchTokenTypeText]];
                                   }
                                   WKEmotionToken *token = [WKEmotionToken new];
                                   token.text = rangeText;
                                   token.range = result.range;
                                   token.imageName = emotion.faceImageName;
                                   
                                   [tokens addObject:token];
                                   index = result.range.location + result.range.length;
                               }
                           }
                           
                       }];
    
    if (index < [text length])
    {
        NSRange range = NSMakeRange(index, [text length] - index);
        NSString *rawText = [text substringWithRange:range];
        [tokens addObject: [WKDefaultToken text:rawText range:range type:WKatchTokenTypeText]];
    }
    
    [_tokens setObject:tokens forKey:text];
    
    return tokens;
}


-(id<WKPEmotion>) emotionByFaceName:(NSString*)faceName{
    for (WKEmotion *emotion in self.emojiFaceArrays) {
        if([emotion.faceName isEqualToString:faceName]){
            return emotion;
        }
    }
    return nil;
}



-(UIImage*) imageNamed:(NSString*)name{
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

-(UIImage*) emojiImageNamed:(NSString*)imageName{
    UIImage *img = [self imageNamed:[NSString stringWithFormat:@"Conversation/Emoji/%@",imageName]];
    if (img) {
        if ([imageName hasPrefix:@"custom_"]) {
            NSLog(@"[Emoji] emojiImageNamed: %@ -> image=LOADED", imageName);
        }
        return img;
    }

    // 兜底：对自定义 Unicode emoji（custom_bomb / custom_party / custom_heart 等），
    // 项目里没放 PNG，在这里用系统字体把 Unicode emoji 渲染成图
    UIImage *rendered = [self fallbackRenderedEmojiForImageName:imageName];
    return rendered;
}

/// 把 imageName 映射到原生 Unicode emoji 并渲染成 32×32 图片（带缓存）
/// 这些 emoji 在 emoji.plist 里像普通系统 emoji 一样（file=ex_xxx, tag=原生 emoji），
/// 走普通 emoji 的渲染路径，不会触发"单个自定义表情大图"逻辑。
- (nullable UIImage *)fallbackRenderedEmojiForImageName:(NSString *)imageName {
    static NSDictionary<NSString *, NSString *> *mapping;
    static dispatch_once_t mapOnce;
    dispatch_once(&mapOnce, ^{
        mapping = @{
            @"ex_bomb": @"💣",
            @"ex_party": @"🎉",
            @"ex_heart": @"❤️",
        };
    });
    NSString *emoji = mapping[imageName];
    if (!emoji) return nil;

    static NSMutableDictionary<NSString *, UIImage *> *cache;
    static dispatch_once_t cacheOnce;
    dispatch_once(&cacheOnce, ^{
        cache = [NSMutableDictionary dictionary];
    });
    UIImage *cached = cache[imageName];
    if (cached) return cached;

    CGSize size = CGSizeMake(32, 32);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:26],
    };
    CGSize textSize = [emoji sizeWithAttributes:attrs];
    CGFloat x = (size.width - textSize.width) / 2.0;
    CGFloat y = (size.height - textSize.height) / 2.0;
    [emoji drawAtPoint:CGPointMake(x, y) withAttributes:attrs];
    UIImage *rendered = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (rendered) cache[imageName] = rendered;
    return rendered;
}

- (NSArray<WKEmotion*> *)emotions {
    return _emojiFaceArrays;
}

-(NSArray<id<WKPEmotion>>*) recentEmotions {
    NSMutableArray<id<WKPEmotion>> *emotions = [NSMutableArray array];
    for (NSDictionary *emotionDict  in self.recentFaceArrays) {
        [emotions addObject:[self toEmotion:emotionDict]];
    }
    return emotions;
}

-(WKEmotion*) toEmotion:(NSDictionary*)emotionDict {
    WKEmotion *emotion = [WKEmotion new];
    emotion.faceId = emotionDict[@"faceId"]?:@"";
    emotion.faceName = emotionDict[@"faceName"]?:@"";
    emotion.faceImageName = emotionDict[@"faceImageName"]?:@"";
    return emotion;
}

-(NSDictionary*) toEmotionDict:(id<WKPEmotion>) emotion {
    return @{
        @"faceId": emotion.faceId,
        @"faceName": emotion.faceName,
        @"faceImageName": emotion.faceImageName,
    };
}


// 最近使用
-(BOOL) recentEmoji:(id<WKPEmotion>)emotion {
    NSMutableArray *recentFaceArrays = [NSMutableArray arrayWithArray:self.recentFaceArrays];
    if( recentFaceArrays.count>0) {
        NSInteger i=0;
        for (NSDictionary *recentEmotionDict in recentFaceArrays) {
            NSString *faceId= recentEmotionDict[@"faceId"];
            if([faceId isEqualToString:emotion.faceId]) {
                if(i==0) {
                    return NO;
                }else {
                    [recentFaceArrays removeObjectAtIndex:i];
                    break;
                }
            }
            i++;
        }
    }
    [recentFaceArrays insertObject:[self toEmotionDict:emotion] atIndex:0];
    
    if(recentFaceArrays.count>recentNum) {
        [recentFaceArrays removeLastObject];
    }
    [[NSUserDefaults standardUserDefaults] setObject:recentFaceArrays forKey:@"recentFaceArrays"];
    
    return YES;
}

@end

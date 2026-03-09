//
//  WKInputMentionCache.m
//
//

#import "WKInputMentionCache.h"

@interface WKInputMentionCache()



@end

@implementation WKInputMentionCache

- (instancetype)init
{
    self = [super init];
    if (self) {
      
    }
    return self;
}

- (NSMutableArray<WKInputMentionItem *> *)items {
    if(!_items) {
        _items = [[NSMutableArray alloc] init];
    }
    return _items;
}

- (NSArray *)allMentionUid:(NSString *)sendText;
{
    
    NSMutableArray *uids = [[NSMutableArray alloc] init];
    if(self.items && self.items.count>0) {
        for (WKInputMentionItem *item in self.items) {
            if([item.name isEqualToString:@"all"]) {
                [uids addObject:@"all"];
                continue;
            }
            NSString *mentionName = [NSString stringWithFormat:@"%@%@",WKInputAtStartChar,item.name];
            if([sendText containsString:mentionName]) {
                [uids addObject:item.uid];
            }
        }
    }
    return uids;
}


- (void)clean
{
    [self.items removeAllObjects];
}

-(NSInteger) itemCount {
    return self.items.count;
}

- (void)addMentionItem:(WKInputMentionItem *)item
{
    [self.items addObject:item];
}

- (WKInputMentionItem *)item:(NSString *)name
{
    __block WKInputMentionItem *item;
    [self.items enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        WKInputMentionItem *object = obj;
        if ([object.name isEqualToString:name])
        {
            item = object;
            *stop = YES;
        }
    }];
    return item;
}


- (WKInputMentionItem *)removeName:(NSString *)name
{
    __block WKInputMentionItem *item;
    [self.items enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        WKInputMentionItem *object = obj;
        if ([object.name isEqualToString:name]) {
            item = object;
            *stop = YES;
        }
    }];
    if (item) {
        [self.items removeObject:item];
    }
    return item;
}

- (NSArray *)matchString:(NSString *)sendText
{
    NSString *pattern = [NSString stringWithFormat:@"%@([^%@]+)%@",WKInputAtStartChar,WKInputAtEndChar,WKInputAtEndChar];
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray *results = [regex matchesInString:sendText options:0 range:NSMakeRange(0, sendText.length)];
    NSMutableArray *matchs = [[NSMutableArray alloc] init];
    for (NSTextCheckingResult *result in results) {
        NSString *name = [sendText substringWithRange:result.range];
        name = [name substringFromIndex:1];
        name = [name substringToIndex:name.length -1];
        [matchs addObject:name];
    }
    return matchs;
}


@end


@implementation WKInputMentionItem

@end

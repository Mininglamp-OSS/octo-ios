//
//  WKStickerPackage.m
//  WuKongBase
//
//  Created by tt on 2021/9/28.
//

#import "WKStickerPackage.h"




@implementation WKSticker

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKSticker *resp = [WKSticker new];
    resp.path = dictory[@"path"];
    resp.width = dictory[@"width"];
    resp.height = dictory[@"height"];
    resp.format = dictory[@"format"];
    resp.sortNum = dictory[@"sort_num"];
    resp.category = dictory[@"category"];
    resp.placeholder = dictory[@"placeholder"];
    return resp;
}

- (NSDictionary *)toMap:(ModelMapType)type {
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
    paramDict[@"path"] = self.path?:@"";
    paramDict[@"width"] = self.width?:@(0);
    paramDict[@"height"] = self.height?:@(0);
    paramDict[@"format"] = self.format?:@"";
    paramDict[@"sort_num"] = self.sortNum?:@(0);
    paramDict[@"category"] = self.category?:@"";
    paramDict[@"placeholder"] = self.placeholder?:@"";
    return paramDict;
}

@end



@implementation WKStickerPackage

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {

    WKStickerPackage *package = [WKStickerPackage new];
    package.title = dictory[@"title"]?:@"";
    package.desc = dictory[@"desc"]?:@"";
    package.category = dictory[@"category"]?:@"";
    package.cover = dictory[@"cover"]?:@"";
    package.added = [dictory[@"added"] boolValue];
    
   NSArray *stickerDicts =  dictory[@"list"];
    if(stickerDicts && stickerDicts.count>0) {
        NSMutableArray *stickers = [NSMutableArray array];
        for (NSDictionary *stickerDict in stickerDicts) {
            [stickers addObject:[WKSticker fromMap:stickerDict type:type]];
        }
        package.list = stickers;
    }
    return package;
}

@end

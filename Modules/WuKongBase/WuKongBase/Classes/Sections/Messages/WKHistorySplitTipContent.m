//
//  WKHistorySpliteTipContent.m
//  WuKongBase
//
//  Created by tt on 2020/10/8.
//

#import "WKHistorySplitTipContent.h"
#import "WKConstant.h"
@implementation WKHistorySplitTipContent


+(NSNumber*) contentType {
    return @(WK_HISTORY_SPLIT);
}

- (NSInteger)realContentType {
    return WK_HISTORY_SPLIT;
}


@end

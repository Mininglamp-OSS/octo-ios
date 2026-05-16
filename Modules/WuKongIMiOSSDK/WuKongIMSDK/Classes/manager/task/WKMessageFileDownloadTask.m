//
//  WKMessageFileDownloadTask.m
//  WuKongIMBase
//
//  Created by tt on 2020/1/16.
//

#import "WKMessageFileDownloadTask.h"

@implementation WKMessageFileDownloadTask

-(instancetype) initWithMessage:(WKMessage*)message; {
    self = [super init];
    if(self) {
        self.message = message;
    }
    return self;
}

- (NSString *)taskId {
    return  [NSString stringWithFormat:@"%u",self.message.clientSeq];
}


@end

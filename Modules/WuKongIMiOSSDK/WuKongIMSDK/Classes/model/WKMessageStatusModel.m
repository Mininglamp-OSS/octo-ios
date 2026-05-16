//
//  WKMessageStatusModel.m
//  WuKongIMBase
//
//  Created by tt on 2019/12/29.
//

#import "WKMessageStatusModel.h"

@implementation WKMessageStatusModel

-(instancetype) initWithClientSeq:(uint32_t)clientSeq status:(WKMessageStatus)status {
    self = [super init];
    if(self) {
        self.clientSeq = clientSeq;
        self.status = status;
    }
    return self;
}

@end

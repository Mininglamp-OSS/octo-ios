//
//  WKMessageExtra.m
//  WuKongIMSDK
//
//  Created by tt on 2022/4/12.
//

#import "WKMessageExtra.h"

@implementation WKMessageExtra

- (BOOL)isEdit {
    if(self.editedAt>0) {
        return true;
    }
    return false;
}

@end

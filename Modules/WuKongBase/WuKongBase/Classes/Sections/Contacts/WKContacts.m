//
//  WKContacts.m
//  WuKongBase
//
//  Created by tt on 2019/12/8.
//

#import "WKContacts.h"

@implementation WKContacts

- (NSString *)displayName {
    if(_displayName) {
        return _displayName;
    }
    return self.name;
}

@end



//
//  WKPacket.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import <Foundation/Foundation.h>
#import "WKHeader.h"
typedef NSString* (^Encode)(void);

@interface WKPacket : NSObject

@property(nonatomic,strong) WKHeader *header;


@end

//
//  WKModelConvert.h
//  WuKongBase
//
//  Created by tt on 2020/1/24.
//

#import <Foundation/Foundation.h>
#import "WKContactsSelectCell.h"
#import "WuKongBase.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKModelConvert : NSObject

+(WKContactsSelect*) toContactsSelect:(WKChannelMember*)channelMember;
@end

NS_ASSUME_NONNULL_END

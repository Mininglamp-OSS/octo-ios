//
//  WKMemberCell.h
//  WuKongBase
//
//  Created by tt on 2022/8/31.
//

#import "WKCell.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKUserOnlineResp.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMemberCell : WKCell

@property(nonatomic,assign) BOOL edit;

@property(nonatomic,assign) BOOL disable;

@property(nonatomic,copy) void(^onCheck)(BOOL check);

- (void)refresh:(WKChannelMember*)member checkOn:(BOOL)checkOn online:(WKUserOnlineResp*)online;

@end

NS_ASSUME_NONNULL_END

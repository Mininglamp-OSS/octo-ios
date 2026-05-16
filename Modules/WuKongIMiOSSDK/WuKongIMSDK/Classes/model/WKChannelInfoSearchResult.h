//
//  WKChannelInfoSearchResult.h
//  WuKongIMSDK
//
//  Created by tt on 2020/5/8.
//

/**
 select t.*,cm.member_name,cm.member_remark from (
 select channel.*,max(channel_member.id) mid from channel,channel_member where channel.channel_id=channel_member.channel_id and channel.channel_type=channel_member.channel_type and (channel.name like '%Zz%' or channel.remark like '%Zz%' or channel_member.member_name like '%Zz%' or channel_member.member_remark like '%Zz%')
 group by channel.channel_id,channel.channel_type
 ) t,channel_member cm where t.channel_id=cm.channel_id and t.channel_type=cm.channel_type and t.mid=cm.id
 */

#import <Foundation/Foundation.h>
#import "WKChannelInfo.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKChannelInfoSearchResult : NSObject

// 频道信息
@property(nonatomic,strong) WKChannelInfo *channelInfo;

@property(nonatomic,strong) NSString *containMemberName; // 包含的成员名字，如果有

@end

NS_ASSUME_NONNULL_END

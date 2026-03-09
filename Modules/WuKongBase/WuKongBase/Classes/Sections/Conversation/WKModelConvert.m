//
//  WKModelConvert.m
//  WuKongBase
//
//  Created by tt on 2020/1/24.
//

#import "WKModelConvert.h"
#import "WKAvatarUtil.h"
@implementation WKModelConvert

+(WKContactsSelect*) toContactsSelect:(WKChannelMember*)channelMember {
    WKContactsSelect *contactsSelect = [WKContactsSelect new];
    contactsSelect.uid =channelMember.memberUid;
    if(channelMember.memberRemark && ![channelMember.memberRemark isEqualToString:@""]) {
        contactsSelect.name = channelMember.memberRemark;
    }else {
        contactsSelect.name =channelMember.memberName;
    }
    if(channelMember.memberAvatar && ![channelMember.memberAvatar isEqualToString:@""]) {
        contactsSelect.avatar = [WKAvatarUtil getFullAvatarWIthPath:channelMember.memberAvatar];
    }else {
        contactsSelect.avatar = [WKAvatarUtil getAvatar:channelMember.memberUid];
    }
    
    return contactsSelect;
}

@end

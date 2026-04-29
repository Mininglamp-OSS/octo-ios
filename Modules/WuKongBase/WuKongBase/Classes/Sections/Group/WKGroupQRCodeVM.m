//
//  WKGroupQRCodeVM.m
//  WuKongBase
//
//  Created by tt on 2020/4/3.
//

#import "WKGroupQRCodeVM.h"
#import "WuKongBase.h"

@implementation WKGroupQRCodeInfoModel

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKGroupQRCodeInfoModel *model = [WKGroupQRCodeInfoModel new];
    model.day = [dictory[@"day"] integerValue];
    model.expire = dictory[@"expire"];
    model.qrcode = dictory[@"qrcode"];
    // YUJ-97: 读 ChannelQrcodeResp.invite_url（跨 Space 扫码入群链接）。
    // 防御 YUJ-53 静默失败模式：显式 NSNull / 非 NSString 都归一为 nil。
    id rawInvite = dictory[@"invite_url"];
    if ([rawInvite isKindOfClass:[NSString class]]) {
        model.inviteUrl = rawInvite;
    } else {
        model.inviteUrl = nil;
    }
    return model;
}

@end

@interface WKGroupQRCodeVM ()

@property(nonatomic,strong) WKChannel *channel;
@end

@implementation WKGroupQRCodeVM

-(instancetype) initWithChannel:(WKChannel*)channel {
    if(self = [super init]) {
        self.channel = channel;
    }
    return self;
}

-(AnyPromise*) requestGetQRCodeInfo {
  return  [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"groups/%@/qrcode",self.channel.channelId] parameters:nil model:WKGroupQRCodeInfoModel.class];
}

@end

//
//  WKGroupQRCodeVM.h
//  WuKongBase
//
//  Created by tt on 2020/4/3.
//

#import "WKBaseVM.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WuKongBase.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKGroupQRCodeInfoModel : WKModel

@property(nonatomic,assign) NSInteger day; // 几天过期
@property(nonatomic,copy) NSString *qrcode; // 二维码内容
@property(nonatomic,copy) NSString *expire; // 过期日期
/// 跨 Space 邀请链接（外部群入群入口，后端 ChannelQrcodeResp.invite_url）
/// 与 qrcode 字段不同：qrcode 是二维码图片内容，invite_url 是可直接分享的文字链接。
/// YUJ-97 / 对应 web PR #971 #972 — 复制到剪贴板用。
@property(nonatomic,copy,nullable) NSString *inviteUrl;


@end


@interface WKGroupQRCodeVM : WKBaseVM

-(instancetype) initWithChannel:(WKChannel*)channel;


/// 请求获取二维码信息
-(AnyPromise*) requestGetQRCodeInfo;

@end

NS_ASSUME_NONNULL_END

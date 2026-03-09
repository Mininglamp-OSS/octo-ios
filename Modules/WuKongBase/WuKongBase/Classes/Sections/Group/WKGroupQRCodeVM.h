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


@end


@interface WKGroupQRCodeVM : WKBaseVM

-(instancetype) initWithChannel:(WKChannel*)channel;


/// 请求获取二维码信息
-(AnyPromise*) requestGetQRCodeInfo;

@end

NS_ASSUME_NONNULL_END

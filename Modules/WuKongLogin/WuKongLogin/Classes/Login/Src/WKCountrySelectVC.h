//
//  WKCountrySelectVC.h
//  WuKongLogin
//
//  Created by tt on 2020/6/8.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKCountrySelectVC : WKBaseVC

// 选择完成
@property(nonatomic,copy) void(^onFinished)(NSDictionary *data);

@end

NS_ASSUME_NONNULL_END

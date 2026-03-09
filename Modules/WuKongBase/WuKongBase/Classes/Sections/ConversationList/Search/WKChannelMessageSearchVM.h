//
//  WKChannelMessageSearchVM.h
//  WuKongBase
//
//  Created by tt on 2020/8/10.
//

#import "WKBaseVM.h"
#import "WKFormSection.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKChannelMessageSearchVM : WKBaseTableVM
@property(nonatomic,strong) WKChannel *channel;
@property(nonatomic,copy) NSString *keyword;

@end

NS_ASSUME_NONNULL_END

//
//  WKChannelSearchResultVC.h
//  WuKongBase
//
//  Created by tt on 2020/8/10.
//

#import <WuKongBase/WuKongBase.h>
#import "WKChannelMessageSearchVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKChannelMessageSearchResultVC : WKBaseTableVC<WKChannelMessageSearchVM*>
@property(nonatomic,strong) WKChannel *channel;
@property(nonatomic,copy) NSString *keyword;
@end

NS_ASSUME_NONNULL_END

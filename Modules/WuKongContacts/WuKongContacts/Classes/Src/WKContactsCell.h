//
//  WKContactsCell.h
//  WuKongContacts
//
//  Created by tt on 2019/12/8.
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
#import "WKContacts.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKContactsCellModel : WKContacts

@property(nonatomic,copy) NSString *firstLetter; // 第一个字母
// 是否禁用
@property(nonatomic,assign) BOOL disable;

// 最后一条数据
@property(nonatomic,assign) BOOL last;

// 第一条数据
@property(nonatomic,assign) BOOL first;

@property(nonatomic,assign) BOOL online; // 是否在线

@property(nonatomic,assign) NSTimeInterval lastOffline; // 最后一次离线时间

@property(nonatomic,strong) WKChannelInfo *channelInfo;

@end

@interface WKContactsCell : WKCell


@end

NS_ASSUME_NONNULL_END

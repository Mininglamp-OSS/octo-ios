//
//  WKConversationListHeaderView.h
//  WuKongBase
//
//  Created by tt on 2021/9/17.
//

#import <UIKit/UIKit.h>
#import "WuKongBase.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationListHeaderView : UIView


@property(nonatomic,assign) BOOL showNetworkError; // 是否显示网络错误

@property(nonatomic,assign) BOOL showPCOnline; // 是否显示PC在线
@property(nonatomic,assign) WKDeviceFlagEnum pcDeviceFlag; // 在线设备标记

@property(nonatomic,strong) UIView *tableHeaderBottomEmptyView;

- (void)viewConfigChange:(WKViewConfigChangeType)type;

@end


@interface WKPCOnlineBarView : UIView

@property(nonatomic,strong) UILabel *tipLbl;

@end

NS_ASSUME_NONNULL_END

//
//  WKMePushSettingVM.h
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WuKongBase.h"
#import "WKFormSection.h"
#import "WKBaseTableVM.h"
NS_ASSUME_NONNULL_BEGIN
@class WKMePushSettingVM;
@protocol WKMePushSettingDelegate <NSObject>

-(void) mePushSettingVMRefreshTable:(WKMePushSettingVM*)vm;

@end

@interface WKMePushSettingVM : WKBaseTableVM

@property(nonatomic,weak) id<WKMePushSettingDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

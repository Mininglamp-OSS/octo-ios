//
//  WKChannelDataManagerDelegateImp.m
//  WuKongDataSource
//
//  Created by tt on 2022/12/2.
//

#import "WKChannelDataManagerDelegateImp.h"
#import <WuKongBase/WuKongBase.h>
#import "WKGroupManagerDelegateImp.h"
#import "WKDataSourceModel.h"
@implementation WKChannelDataManagerDelegateImp

- (void)channelDataManager:(WKChannelDataManager *)manager members:(WKChannel *)channel keyword:(NSString *)keyword page:(NSInteger)page limit:(NSInteger)limit complete:(void (^)(NSError * _Nullable, NSArray<WKChannelMember *> * __nullable))complete {
   
}

@end

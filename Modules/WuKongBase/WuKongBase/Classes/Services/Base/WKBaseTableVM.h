//
//  WKBaseTableVM.h
//  WuKongBase
//
//  Created by tt on 2020/6/21.
//

#import "WKFormSection.h"
#import "WKLabelItemCell.h"
#import "WKSwitchItemCell.h"
#import "WKButtonItemCell.h"
NS_ASSUME_NONNULL_BEGIN
@class WKBaseTableVM;
@protocol WKBaseTableVMDelegate <NSObject>



/// 重新加载数据
/// @param vm <#vm description#>
-(void) baseTableReloadData:(WKBaseTableVM*)vm;

-(void) baseTableReloadRemoteData:(WKBaseTableVM*)vm;

-(void) baseTableResetPullupState:(WKBaseTableVM*)vm;
@end

@interface WKBaseTableVM : WKBaseVM

@property(nonatomic,weak) id<WKBaseTableVMDelegate> delegateR;

// 是否启用上拉
@property(nonatomic,assign) BOOL enablePullup;

-(NSArray<WKFormSection*>*) tableSections;

-(NSArray<NSDictionary*>*) tableSectionMaps;


/// 请求数据
/// @param complete <#complete description#>
-(void) requestData:(void(^)(NSError * __nullable error))complete;


/// 上拉请求
/// @param complete <#complete description#>
-(void) pullup:(void(^)(BOOL noMore))complete;


/// 重新加载数据（触发tableview的 reloadData）
-(void) reloadData;

// 重新加载远程数据
-(void) reloadRemoteData;

// 重置上拉状态
-(void) resetPullupState;

@end

NS_ASSUME_NONNULL_END

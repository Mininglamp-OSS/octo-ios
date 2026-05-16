//
//  WKBaseTableVC.h
//  WuKongBase
//
//  Created by tt on 2020/2/2.
//

#import "WuKongBase.h"
#import "WKFormSection.h"
#import "WKTouchTableView.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKBaseTableVC<__covariant VM:WKBaseVM*> : WKBaseVC<VM>

@property(nonatomic,strong) UITableView *tableView;

@property(nonatomic,strong) NSMutableArray<WKFormSection*> *items;


/// table的frame
-(CGRect) tableViewFrame;

/**
 将字典数据转换为WKFormSection

 @param sectionArray <#sectionArray description#>
 @return <#return value description#>
 */
-(NSArray<WKFormSection*>*) toSections:(NSArray<NSDictionary*>*) sectionArray;


/// 重新加载数据
-(void)reloadData;


/// 重新加载远程数据
-(void)reloadRemoteData;

/// 重置上拉状态
-(void) resetPullupState;


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

// head的背景颜色
-(UIColor*) headColor;


@end

NS_ASSUME_NONNULL_END

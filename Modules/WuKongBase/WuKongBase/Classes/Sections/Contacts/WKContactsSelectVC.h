//
//  WKContactsSelectVC.h
//  WuKongContacts
//
//  Created by tt on 2020/1/19.
//

#import <Foundation/Foundation.h>
#import "WKBaseVC.h"
#import "WKContactsSelectCell.h"

NS_ASSUME_NONNULL_BEGIN



// 联系人完成选择
typedef void (^ContactsFinishedSelect)(NSArray<NSString*>* uids);

@interface WKContactsSelectVC : WKBaseVC


@property(nonatomic,strong) UITableView *tableView;

@property(nonatomic,assign) BOOL showBack; // modal模式的时候需要设置true 要不然没返回箭头

@property(nonatomic,copy) void(^onDealloc)(void);

/**
选择模式
 */
@property(nonatomic,assign) WKContactsMode mode;

@property(nonatomic,assign) BOOL mentionAll; // 是否显示@所有人
///最大可选人数
@property (nonatomic,assign) NSInteger maxSelectMembers;

/**
 联系人选择列表
 */
@property(nonatomic,strong) NSArray<WKContactsSelect*> *data;

/**
 禁言选择的用户uid
 */
@property(nonatomic,strong) NSArray<NSString*> *disables;

@property(nonatomic,strong) NSArray<NSString*> *hiddenUsers; // 隐藏的用户

/// 默认被选中的用户集合
@property(nonatomic, strong) NSArray<NSString*> *selecteds;

/**
 完成选择
 */
@property(nonatomic,copy) ContactsFinishedSelect onFinishedSelect;

-(void) parseData:(NSArray<WKContactsSelect*>*) data;

-(void) requestData;

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END

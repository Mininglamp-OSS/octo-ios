//
//  WKFuncGroupEditItemCell.h
//  WuKongBase
//
//  Created by tt on 2022/5/5.
//

#import "WuKongBase.h"
#import "WKFuncGroupEditItemModel.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKFuncGroupEditItemCell : UITableViewCell

@property(nonatomic,strong) UISwitch *enableSwitch;

@property(nonatomic,copy) void(^onSwitch)(BOOL on);

-(void) refresh:(WKFuncGroupEditItemModel*) item;

@end

NS_ASSUME_NONNULL_END

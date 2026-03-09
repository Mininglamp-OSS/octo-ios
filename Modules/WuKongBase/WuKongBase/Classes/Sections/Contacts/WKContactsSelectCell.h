//
//  WKContactsSelectCell.h
//  WuKongContacts
//
//  Created by tt on 2020/1/19.
//

#import <Foundation/Foundation.h>
#import "WKContacts.h"
#import "WKCell.h"
#import "WKCheckBox.h"
#import "WKImageView.h"
#import "WKUserAvatar.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKContactsSelect : WKContacts

@property(nonatomic,assign) WKContactsMode mode;
// 是否禁用
@property(nonatomic,assign) BOOL disable;

// 最后一条数据
@property(nonatomic,assign) BOOL last;

// 第一条数据
@property(nonatomic,assign) BOOL first;

// 是否被选择
@property(nonatomic,assign) BOOL selected;

@end

typedef void (^stateChangeCheckBlock)(WKContactsSelect *model);

@interface WKContactsSelectCell : WKCell

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;

@property(nonatomic,strong) WKContactsSelect *contactSelectModel;

@property(nonatomic,strong) WKCheckBox *checkBox;

@property(nonatomic, strong) stateChangeCheckBlock stateChangeCheckBk;

-(void) refreshWithModel:(id)cellModel;


@end

NS_ASSUME_NONNULL_END

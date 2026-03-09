//
//  WKFuncGroupEditItemModel.h
//  WuKongBase
//
//  Created by tt on 2022/5/6.
//

#import <Foundation/Foundation.h>
#import "WKPanelFuncItemProto.h"
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSInteger {
    WKFuncGroupEditItemTypeFavorite, // 个人收藏
    WKFuncGroupEditItemTypeMore, // 更多app
} WKFuncGroupEditItemType;


@interface WKFuncGroupEditItemModel : NSObject

@property(nonatomic,copy) NSString *sid;
@property(nonatomic,strong) UIImage *itemIcon;
@property(nonatomic,copy) NSString *title;
@property(nonatomic,assign) BOOL allowEdit;
@property(nonatomic,assign) NSInteger sort;
@property(nonatomic,assign) BOOL disable;
@property(nonatomic,assign) WKFuncGroupEditItemType type; // 区域 0. 个人收藏 1.更多app
@property(nonatomic,assign) WKChannelType channelType;

-(instancetype) initWithFuncItem:(id<WKPanelFuncItemProto>)funcItem;

@end

NS_ASSUME_NONNULL_END

//
//  WKFuncGroupEditItemModel.m
//  WuKongBase
//
//  Created by tt on 2022/5/6.
//

#import "WKFuncGroupEditItemModel.h"


@interface WKFuncGroupEditItemModel ()


@end

@implementation WKFuncGroupEditItemModel

-(instancetype) initWithFuncItem:(id<WKPanelFuncItemProto>)funcItem {
    WKFuncGroupEditItemModel *model = [WKFuncGroupEditItemModel new];
    model.channelType = funcItem.channelType;
    model.sid = funcItem.sid;
    model.itemIcon = funcItem.itemIcon;
    model.title = [funcItem title];
    model.allowEdit = [funcItem allowEdit];
    model.sort = [funcItem sort];
    model.disable = [funcItem disable];
    return model;
}

@end


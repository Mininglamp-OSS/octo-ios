//
//  WKMoreItemModel.m
//  WuKongBase
//
//  Created by tt on 2020/1/12.
//

#import "WKMoreItemModel.h"
#import "WKCommonMoreItemCell.h"
@interface WKMoreItemModel ()




@end

@implementation WKMoreItemModel

+(WKMoreItemModel*) initWithImage:(UIImage*)image title:(NSString*)title onClick:(onClickBlock)onClickBlock {
    WKMoreItemModel *model = [WKMoreItemModel new];
    model.image = image;
    model.title = title;
    model.oncClickBLock = onClickBlock;
    return model;
}

+(Class) moreItemCellClass {
    return [WKCommonMoreItemCell class];
}
@end

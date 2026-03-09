//
//  WKFormItemModel.m
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import "WKFormItemModel.h"
#import "WKFormItemCell.h"

@interface WKFormItemModel ()


@end

@implementation WKFormItemModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.bottomLeftSpace  = @(20.0f);
    }
    return self;
}
- (Class)cell {
    return WKFormItemCell.class;
}

- (CGFloat)cellHeight {
    if(_cellHeight>0) {
        return _cellHeight;
    }
    return [self defaultCellHeight];
}

-(CGFloat) defaultCellHeight {
    return 54.0f;
}
@end

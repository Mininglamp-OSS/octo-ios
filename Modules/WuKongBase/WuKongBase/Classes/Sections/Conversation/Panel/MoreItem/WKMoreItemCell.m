//
//  WKMoreItem.m
//  WuKongBase
//
//  Created by tt on 2020/1/12.
//

#import "WKMoreItemCell.h"

@interface WKMoreItemCell ()


@end

@implementation WKMoreItemCell

+(NSString *)reuseIdentifier {
    return NSStringFromClass([self class]);
}

-(void) refresh:(WKMoreItemModel*)model{
    
}

@end

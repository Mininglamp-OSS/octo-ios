//
//  WKFuncItemButton.m
//  WuKongBase
//
//  Created by tt on 2020/2/24.
//

#import "WKFuncItemButton.h"

@implementation WKFuncItemButton

- (CGRect)imageRectForContentRect:(CGRect)contentRect {
    return CGRectMake(0.0f, 0.0f, contentRect.size.width, contentRect.size.height);
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    if(self.onSelected) {
        self.onSelected();
    }
}

@end

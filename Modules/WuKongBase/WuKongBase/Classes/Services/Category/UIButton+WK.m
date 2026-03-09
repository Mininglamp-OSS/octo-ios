//
//  UIButton+WK.m
//  WuKongBase
//
//  Created by tt on 2022/7/21.
//

#import "UIButton+WK.h"


typedef void(^WK_ButtonEventsBlock)(void);

@interface UIButton ()

/** 事件回调的block */
@property (nonatomic, copy) WK_ButtonEventsBlock lim_buttonEventsBlock;

@end

@implementation UIButton (WK)

//------- 添加属性 -------//

static void *lim_buttonEventsBlockKey = &lim_buttonEventsBlockKey;

- (WK_ButtonEventsBlock)lim_buttonEventsBlock {
    return objc_getAssociatedObject(self, &lim_buttonEventsBlockKey);
}

- (void)setLim_buttonEventsBlock:(WK_ButtonEventsBlock)lim_buttonEventsBlock {
    objc_setAssociatedObject(self, &lim_buttonEventsBlockKey, lim_buttonEventsBlock, OBJC_ASSOCIATION_COPY);
}

/**
 给按钮绑定事件回调block
 
 @param block 回调的block
 @param controlEvents 回调block的事件
 */
- (void)lim_addEventHandler:(void (^)(void))block forControlEvents:(UIControlEvents)controlEvents {
    self.lim_buttonEventsBlock = block;
    [self addTarget:self action:@selector(lim_blcokButtonClicked) forControlEvents:controlEvents];
}

// 按钮点击
- (void)lim_blcokButtonClicked {
    if (self.lim_buttonEventsBlock) {
        self.lim_buttonEventsBlock();
    }
}



@end

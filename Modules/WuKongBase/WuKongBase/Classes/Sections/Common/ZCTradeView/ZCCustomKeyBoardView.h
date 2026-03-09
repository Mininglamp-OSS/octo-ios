//
//  ZCCustomKeyBoardView.h
//  qiyunxin
//
//  Created by Qiyunxin01 on 16/6/18.
//  Copyright © 2016年 aiti. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol CustomNumberKeyBoardDelegate <NSObject>

- (void) numberKeyBoardInput:(NSString*) number;
- (void) numberKeyBoardBackspace:(NSString*) number;
- (void) numberKeyBoardFinish;

@end
@interface ZCCustomKeyBoardView : UIView
@property(nonatomic, assign) id<CustomNumberKeyBoardDelegate> delegate;

@end

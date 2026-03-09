//
//  ZCCustomKeyBoardView.m
//  qiyunxin
//
//  Created by Qiyunxin01 on 16/6/18.
//  Copyright © 2016年 aiti. All rights reserved.
//
#define kButtonSizeWidth     [UIScreen mainScreen].bounds.size.width/3

#define kButtonSizeHeight 238.0f/4
#import "ZCCustomKeyBoardView.h"

@implementation ZCCustomKeyBoardView
-(instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        [self customView:frame];
    }
    return self;
}
-(void)customView:(CGRect)frame{
    // set the frame
    self.frame = CGRectMake(frame.origin.x, frame.origin.y, 320.0f, 238.0f);
    NSArray * dataArr = @[@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@".",@"0",@"<<-"];
    self.backgroundColor = [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
    for (int x = 0; x < 12; x++)
    {
        UIButton *btn = [[UIButton alloc]init];
        [btn setFrame:CGRectMake( x%3*(kButtonSizeWidth), x/3*(kButtonSizeHeight),
                                 kButtonSizeWidth,kButtonSizeHeight)];
        btn.layer.borderWidth = 0.5f;
        btn.layer.borderColor = [UIColor colorWithRed:202.0f/255.0f green:202.0f/255.0f blue:202.0f/255.0f alpha:1.0f].CGColor;
        btn.titleLabel.font = [UIFont systemFontOfSize:20.0f];
        [btn setTitle:[NSString stringWithFormat:@"%@",dataArr[x]] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        //      [UIColor colorWithRed:190.0f/255.0f green:190.0f/255.0f blue:190.0f/255.0f alpha:1.0f]
        if (x <= 9)
        {
            if (x == 9)
            {
                btn.backgroundColor = [UIColor colorWithRed:216.0f/255.0f green:216.0f/255.0f blue:213.0f/255.0f alpha:1.0f];
            }
            [btn setTag:(x + 1)];
        }
        else if (x == 11)
        {
            btn.backgroundColor = [UIColor colorWithRed:216.0f/255.0f green:216.0f/255.0f blue:213.0f/255.0f alpha:1.0f];
            
            btn.tag = x;
        }
        else if (x == 10)
        {
            btn.tag = 0;
        }
        else
            
        {
            // btn.tag = x;
        }
        [btn addTarget:self action:@selector(numbleButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
    }
    
}
-(void)numbleButtonClicked:(UIButton*)btn{
    
    NSInteger number = btn.tag;
    
    
    
    // no delegate, print log info
    if (nil == _delegate)
    {
        //        NSLog(@"button tag [%ld]",(long)number);
        return;
    }
    
    if (number <= 9 && number >= 0)
    {
        [_delegate numberKeyBoardInput:[NSString stringWithFormat:@"%ld",(long)number]];
        return;
    }
    
    if (10 == number)
    {
        [_delegate numberKeyBoardInput:@"."];
        return;
    }
    
    if (11 == number)
    {
        [_delegate numberKeyBoardBackspace:@""];
        
        //        [_delegate numberKeyBoardFinish];
        return;
    }
    
}
/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect {
 // Drawing code
 }
 */

@end

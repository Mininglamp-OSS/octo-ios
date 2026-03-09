//
//  CWVoiceView.m
//  QQVoiceDemo
//
//  Created by 陈旺 on 2017/9/2.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWVoiceView.h"
#import "UIView+CWChat.h"
#import "CWTalkBackView.h"
#import "CWRecordView.h"
#import "CWChangeVoiceView.h"
#import "WuKongBase.h"

@interface CWVoiceView ()<UIScrollViewDelegate>

@property (nonatomic,weak) UIScrollView *contentScrollView; // 承载内容的视图

@property (nonatomic,weak) CWTalkBackView *talkBackView;    // 对讲视图
@property (nonatomic,weak) CWRecordView *recordView;        // 录音视图
@property (nonatomic,weak) CWChangeVoiceView *voiceChangeView; // 变声视图

@property (nonatomic,weak) UIView *smallCirle; // 蓝色小圆点
@property (nonatomic,weak) UIView *bottomView; // 下方（变声、对讲、录音）的view

@property (nonatomic,strong) NSArray *bottomsLabels; // bottomView上的标签数组
@property (nonatomic,weak) UILabel *selectLabel;    // 当前选中的label

@property(nonatomic,assign) NSInteger count;

@end

@implementation CWVoiceView
{
    CGFloat _labelDistance;
    CGPoint _currentContentOffSize;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.count = 2;
        self.backgroundColor = [UIColor whiteColor];
       
    }
    return self;
}

- (void)setupSubViews {
    // 设置内容滚动视图
    [self contentScrollView];
    // 设置对讲界面
    [self talkBackView];
    // 设置录音界面
    [self recordView];
    // 设置变声界面
//    [self voiceChangeView];
    // 设置下方三个标签界面
    [self bottomView];
    // 设置标志小圆点
    [self setupSmallCircleView];
    
    _currentContentOffSize = CGPointMake(0, 0);
    // 设置对讲标签为选中
//    [self setupSelectLabel:self.bottomsLabels[1]];
    [self setupSelectLabel:self.bottomsLabels[0]];
}

- (void)setupSelectLabel:(UILabel *)label {
    _selectLabel.textColor = kNormalBackGroudColor;
    label.textColor = kSelectBackGroudColor;
    _selectLabel = label;
}

#pragma mark - subviews
- (UIScrollView *)contentScrollView {
    if (_contentScrollView == nil) {
        UIScrollView *scrollV = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.cw_width, self.cw_height)];
        scrollV.pagingEnabled = YES;
        scrollV.contentSize = CGSizeMake(self.cw_width * self.count, 0);
        scrollV.contentOffset = CGPointMake(0, 0);
        scrollV.showsHorizontalScrollIndicator = NO;
        scrollV.delegate = self;
        [self addSubview:scrollV];
        _contentScrollView = scrollV;
    }
    return _contentScrollView;
}

- (CWTalkBackView *)talkBackView {
    if (_talkBackView == nil) {
//        CWTalkBackView *talkView = [[CWTalkBackView alloc] initWithFrame:CGRectMake(self.cw_width, 0, self.cw_width, self.contentScrollView.cw_height)];
         CWTalkBackView *talkView = [[CWTalkBackView alloc] initWithFrame:CGRectMake(0, 0, self.cw_width, self.contentScrollView.cw_height)];
        [self.contentScrollView addSubview:talkView];
        _talkBackView = talkView;
        _talkBackView.delegate = self.talkBackViewDelegate;
        _talkBackView.playDelegate = self.playViewDelegate;
    }
    return _talkBackView;
}

- (CWRecordView *)recordView {
    if (_recordView == nil) {
        CWRecordView *recordView = [[CWRecordView alloc] initWithFrame:CGRectMake(self.cw_width * 1, 0, self.cw_width, self.contentScrollView.cw_height)];
        recordView.playViewDelegate = self.playViewDelegate;
        recordView.recordViewDelegate = self.voiceRecordViewDelegate;
        [self.contentScrollView addSubview:recordView];
        _recordView = recordView;
    }
    return _recordView;
}

- (CWChangeVoiceView *)voiceChangeView {
    if (_voiceChangeView == nil) {
        CWChangeVoiceView *voiceChangeView = [[CWChangeVoiceView alloc] initWithFrame:CGRectMake(0, 0, self.cw_width, self.contentScrollView.cw_height)];
        voiceChangeView.delegate = self.voiceChangePlayDelegate;
        [self.contentScrollView addSubview:voiceChangeView];
        _voiceChangeView = voiceChangeView;
    }
    return _voiceChangeView;
}

- (UIView *)bottomView {
    if (_bottomView == nil) {
        UIView *bottomV = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.cw_height - 45, self.cw_width, 25)];
        [self addSubview:bottomV];
//        bottomV.backgroundColor = [UIColor redColor];
        _bottomView = bottomV;
        [self setupBottomViewSubviews];
    }
    return _bottomView;
}

- (void)setupBottomViewSubviews {
    CGFloat margin = 10;
//    NSArray *titleArr = @[@"变声",@"对讲",@"录音"];
    NSArray *titleArr = @[LLang(@"对讲"),LLang(@"录音")];
    
//    _bottomsLabels = [NSMutableArray array];
    
////    UILabel *talkBackLabel = [self labelWithText:titleArr[1]];
//     UILabel *talkBackLabel = [self labelWithText:titleArr[0]];
////    talkBackLabel.center = CGPointMake(self.bottomView.cw_width / 2.0, self.bottomView.cw_height / 2.0);
//    talkBackLabel.center = CGPointMake(self.bottomView.cw_width / 2.0, self.bottomView.cw_height / 2.0);
////    talkBackLabel.textColor = kSelectBackGroudColor;
//    [self.bottomView addSubview:talkBackLabel];
    
//    UILabel *label = [self labelWithText:titleArr[0]];
//    label.center = CGPointMake(talkBackLabel.cw_left - margin - label.cw_width / 2.0, self.bottomView.cw_height / 2.0);
//    [self.bottomView addSubview:label];
    
//    UILabel *recordLabel = [self labelWithText:titleArr[2]];
    
    
    //    UILabel *talkBackLabel = [self labelWithText:titleArr[1]];
    UILabel *talkBackLabel = [self labelWithText:titleArr[0]];
//    [talkBackLabel setBackgroundColor:[UIColor greenColor]];
    //    talkBackLabel.center = CGPointMake(self.bottomView.cw_width / 2.0, self.bottomView.cw_height / 2.0);
    talkBackLabel.center = CGPointMake(self.cw_width/2.0f, self.bottomView.cw_height / 2.0);
    //    talkBackLabel.textColor = kSelectBackGroudColor;
        [self.bottomView addSubview:talkBackLabel];
    
    UILabel *recordLabel = [self labelWithText:titleArr[1]];
//       [recordLabel setBackgroundColor:[UIColor blueColor]];
    recordLabel.center = CGPointMake(talkBackLabel.cw_right + recordLabel.cw_width/2.0f + margin, self.bottomView.cw_height / 2.0);
       [self.bottomView addSubview:recordLabel];
    
    _labelDistance = recordLabel.center.x - talkBackLabel.center.x;
    
    //self.bottomsLabels = @[label,talkBackLabel,recordLabel];
    self.bottomsLabels = @[talkBackLabel,recordLabel];
}

- (UILabel *)labelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.textColor = kNormalBackGroudColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:14];
    [label sizeToFit];
    return label;
}

- (void)setupSmallCircleView {
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 8)];
    view.backgroundColor = kSelectBackGroudColor;
    view.layer.cornerRadius = view.cw_width / 2.0;
    view.center = CGPointMake(self.cw_width / 2.0, self.bottomView.cw_top - view.cw_height / 2.0);
    [self addSubview:view];
    self.smallCirle = view;
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    CGFloat scrollDistance = scrollView.contentOffset.x - _currentContentOffSize.x;
    CGFloat transtionX = scrollDistance / self.contentScrollView.cw_width * _labelDistance;
    self.bottomView.transform = CGAffineTransformMakeTranslation(-transtionX, 0);
    
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSInteger index = scrollView.contentOffset.x / self.contentScrollView.cw_width;
    [self setupSelectLabel:self.bottomsLabels[index]];
}

#pragma mark - setter
- (void)setState:(CWVoiceState)state {
    _state = state;
    self.bottomView.hidden = state != CWVoiceStateDefault;
    self.smallCirle.hidden = state != CWVoiceStateDefault;
    self.contentScrollView.scrollEnabled = state == CWVoiceStateDefault;
}

@end












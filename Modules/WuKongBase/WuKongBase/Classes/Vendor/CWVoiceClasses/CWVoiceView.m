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
#import "CWSpeechToTextView.h"
#import "CWChangeVoiceView.h"
#import "WKVoiceInputView.h"
#import "WuKongBase.h"

@interface CWVoiceView ()<UIScrollViewDelegate>

@property (nonatomic,weak) UIScrollView *contentScrollView;

@property (nonatomic,weak) WKVoiceInputView *voiceInputView;       // 语音输入视图
@property (nonatomic,weak) CWSpeechToTextView *speechToTextView;   // 语音转文字视图
@property (nonatomic,weak) CWTalkBackView *talkBackView;           // 对讲视图
@property (nonatomic,weak) CWChangeVoiceView *voiceChangeView;

@property (nonatomic,weak) UIView *smallCirle;
@property (nonatomic,weak) UIView *bottomView;

@property (nonatomic,strong) NSArray *bottomsLabels;
@property (nonatomic,strong) NSArray *labelCenterXs;
@property (nonatomic,weak) UILabel *selectLabel;

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
        self.backgroundColor = [UIColor whiteColor];
    }
    return self;
}

- (void)setupSubViews {
    // 计算 tab 数量
    self.count = self.voiceInputEnabled ? 3 : 2;

    [self contentScrollView];

    NSInteger pageIndex = 0;

    // 语音输入（第一个 tab，如果启用）
    if (self.voiceInputEnabled) {
        [self setupVoiceInputViewAtIndex:pageIndex++];
    }
    // 语音转文字
    [self setupSpeechToTextViewAtIndex:pageIndex++];
    // 对讲
    [self setupTalkBackViewAtIndex:pageIndex++];

    [self bottomView];
    [self setupSmallCircleView];

    _currentContentOffSize = CGPointMake(0, 0);
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

- (void)setupVoiceInputViewAtIndex:(NSInteger)index {
    WKVoiceInputView *view = [[WKVoiceInputView alloc] initWithFrame:CGRectMake(self.cw_width * index, 0, self.cw_width, self.contentScrollView.cw_height)];
    view.delegate = self.voiceInputDelegate;
    [self.contentScrollView addSubview:view];
    _voiceInputView = view;
}

- (void)setupSpeechToTextViewAtIndex:(NSInteger)index {
    CWSpeechToTextView *sttView = [[CWSpeechToTextView alloc] initWithFrame:CGRectMake(self.cw_width * index, 0, self.cw_width, self.contentScrollView.cw_height)];
    sttView.delegate = self.speechToTextDelegate;
    [self.contentScrollView addSubview:sttView];
    _speechToTextView = sttView;
}

- (void)setupTalkBackViewAtIndex:(NSInteger)index {
    CWTalkBackView *talkView = [[CWTalkBackView alloc] initWithFrame:CGRectMake(self.cw_width * index, 0, self.cw_width, self.contentScrollView.cw_height)];
    talkView.delegate = self.talkBackViewDelegate;
    talkView.playDelegate = self.playViewDelegate;
    [self.contentScrollView addSubview:talkView];
    _talkBackView = talkView;
}

- (UIView *)bottomView {
    if (_bottomView == nil) {
        UIView *bottomV = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.cw_height - 45, self.cw_width, 25)];
        [self addSubview:bottomV];
        _bottomView = bottomV;
        [self setupBottomViewSubviews];
    }
    return _bottomView;
}

- (void)setupBottomViewSubviews {
    CGFloat margin = 10;

    NSMutableArray *titleArr = [NSMutableArray array];
    if (self.voiceInputEnabled) {
        [titleArr addObject:LLang(@"语音输入")];
    }
    [titleArr addObject:LLang(@"语音转文字")];
    [titleArr addObject:LLang(@"对讲")];

    // 通用居中排列算法
    NSMutableArray *labels = [NSMutableArray array];
    CGFloat totalWidth = 0;
    for (NSString *title in titleArr) {
        UILabel *label = [self labelWithText:title];
        [labels addObject:label];
        totalWidth += label.cw_width;
    }
    totalWidth += margin * (labels.count - 1);

    CGFloat startX = (self.cw_width - totalWidth) / 2.0;
    NSMutableArray *centerXs = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)labels.count; i++) {
        UILabel *label = labels[i];
        label.center = CGPointMake(startX + label.cw_width / 2.0, self.bottomView.cw_height / 2.0);
        [self.bottomView addSubview:label];
        [centerXs addObject:@(label.center.x)];
        startX += label.cw_width + margin;
    }

    self.bottomsLabels = labels;
    self.labelCenterXs = centerXs;

    if (labels.count >= 2) {
        _labelDistance = [centerXs[1] floatValue] - [centerXs[0] floatValue];
    }
}

- (UILabel *)labelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.textColor = kNormalBackGroudColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:14];
    label.userInteractionEnabled = YES;
    [label sizeToFit];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTabLabelTapped:)];
    [label addGestureRecognizer:tap];

    return label;
}

- (void)onTabLabelTapped:(UITapGestureRecognizer *)tap {
    UILabel *label = (UILabel *)tap.view;
    NSInteger index = [self.bottomsLabels indexOfObject:label];
    if (index == NSNotFound) return;

    [self.contentScrollView setContentOffset:CGPointMake(self.cw_width * index, 0) animated:YES];
    [self setupSelectLabel:label];
    [self updateDotPositionForPage:index];

    // 离开语音输入 Tab 时取消录音
    NSInteger voiceInputIndex = self.voiceInputEnabled ? 0 : -1;
    if (index != voiceInputIndex) {
        [self.voiceInputView cancelIfRecording];
    }
}

- (void)setupSmallCircleView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 8)];
    view.backgroundColor = kSelectBackGroudColor;
    view.layer.cornerRadius = view.cw_width / 2.0;
    CGFloat initialCenterX = (self.labelCenterXs.count > 0)
        ? [self.labelCenterXs[0] floatValue]
        : self.cw_width / 2.0;
    view.center = CGPointMake(initialCenterX, self.bottomView.cw_top - view.cw_height / 2.0);
    [self addSubview:view];
    self.smallCirle = view;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat pageWidth = self.contentScrollView.cw_width;
    CGFloat offsetX = scrollView.contentOffset.x;

    NSInteger currentPage = (NSInteger)(offsetX / pageWidth);
    CGFloat fraction = (offsetX - currentPage * pageWidth) / pageWidth;

    if (currentPage < 0) currentPage = 0;
    if (currentPage >= (NSInteger)self.labelCenterXs.count) currentPage = self.labelCenterXs.count - 1;
    NSInteger nextPage = MIN(currentPage + 1, (NSInteger)self.labelCenterXs.count - 1);

    CGFloat currentCenterX = [self.labelCenterXs[currentPage] floatValue];
    CGFloat nextCenterX = [self.labelCenterXs[nextPage] floatValue];
    CGFloat dotCenterX = currentCenterX + (nextCenterX - currentCenterX) * fraction;

    // 只移动小圆点，bottomView 固定不动
    self.smallCirle.center = CGPointMake(dotCenterX, self.smallCirle.center.y);
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSInteger index = scrollView.contentOffset.x / self.contentScrollView.cw_width;
    if (index < 0) index = 0;
    if (index >= (NSInteger)self.bottomsLabels.count) index = self.bottomsLabels.count - 1;
    [self setupSelectLabel:self.bottomsLabels[index]];
    [self updateDotPositionForPage:index];

    // 离开语音输入 Tab 时取消录音
    NSInteger voiceInputIndex = self.voiceInputEnabled ? 0 : -1;
    if (index != voiceInputIndex) {
        [self.voiceInputView cancelIfRecording];
    }
}

- (void)updateDotPositionForPage:(NSInteger)page {
    if (page < 0 || page >= (NSInteger)self.labelCenterXs.count) return;
    CGFloat centerX = [self.labelCenterXs[page] floatValue];
    self.smallCirle.center = CGPointMake(centerX, self.smallCirle.center.y);
}

#pragma mark - setter

- (void)setState:(CWVoiceState)state {
    _state = state;
    self.bottomView.hidden = state != CWVoiceStateDefault;
    self.smallCirle.hidden = state != CWVoiceStateDefault;
    self.contentScrollView.scrollEnabled = state == CWVoiceStateDefault;
}

- (void)cancelVoiceInputIfRecording {
    [self.voiceInputView cancelIfRecording];
}

@end

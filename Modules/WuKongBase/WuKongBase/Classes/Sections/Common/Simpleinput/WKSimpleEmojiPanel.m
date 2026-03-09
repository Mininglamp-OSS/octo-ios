//
//  WKSimpleEmojiPanel.m
//  WuKongBase
//
//  Created by tt on 2020/11/18.
//

#import "WKSimpleEmojiPanel.h"
#import "WKEmojiContentView.h"
#import "WKApp.h"
#import "WuKongBase.h"
#define barHeight 44.0f

@interface WKSimpleEmojiPanel ()

@property(nonatomic,strong) WKEmojiContentView *emojiContentView;

@property(nonatomic,strong) UIView *barView;
@property(nonatomic,strong) UIButton *sendBtn;

@end

@implementation WKSimpleEmojiPanel

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        [self addSubview:self.emojiContentView];
        [self addSubview:self.barView];
        [self.barView addSubview:self.sendBtn];
    }
    return self;
}

-(void) layoutPanel:(CGFloat)height {
    self.frame = CGRectMake(0, 0, WKScreenWidth,height);
    
    self.emojiContentView.frame = self.frame;
    
    if(self.lim_height>0) {
        self.emojiContentView.lim_height = self.lim_height - barHeight - [self safeBottom];
        self.barView.hidden = NO;
        self.barView.lim_top = self.lim_height - self.barView.lim_height - [self safeBottom];
    }else{
        self.barView.hidden = YES;
    }
    
    
}

- (WKEmojiContentView *)emojiContentView {
    if(!_emojiContentView) {
        __weak typeof(self) weakSelf = self;
        _emojiContentView = [[WKEmojiContentView alloc] init];
        [_emojiContentView setBackgroundColor:[WKApp shared].config.backgroundColor];
        [_emojiContentView setOnEmoji:^(WKEmotion * _Nonnull emoji) {
            if(weakSelf.onEmoji) {
                weakSelf.onEmoji(emoji);
            }
        }];
    }
    return _emojiContentView;
}

- (UIView *)barView {
    if(!_barView) {
        _barView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, barHeight)];
    }
    return _barView;
}
-(CGFloat) safeBottom {
    CGFloat safeBottom = 0.0f;
    if (@available(iOS 11.0, *)) {
        safeBottom = [[UIApplication sharedApplication].keyWindow safeAreaInsets].bottom;
    }
    return safeBottom;
}

- (UIButton *)sendBtn {
    if(!_sendBtn) {
        CGFloat width = 80.0f;
        _sendBtn = [[UIButton alloc] initWithFrame:CGRectMake(WKScreenWidth - width, 0.0f, width, barHeight)];
        [_sendBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_sendBtn setTitle:LLang(@"发送") forState:UIControlStateNormal];
        [_sendBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        if([WKApp shared].config.style == WKSystemStyleDark) {
            _sendBtn.layer.shadowColor = [UIColor colorWithRed:15.0f/255.0f green:15.0f/255.0f blue:15.0f/255.0f alpha:1.0].CGColor;
        }else{
            _sendBtn.layer.shadowColor = [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0].CGColor;
        }
       
        _sendBtn.layer.shadowOffset = CGSizeMake(-2.0f, 0.0f);
        _sendBtn.layer.shadowOpacity = 1.0f;
        [_sendBtn addTarget:self action:@selector(sendPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _sendBtn;
}

-(void) sendPressed {
    if(self.onSend) {
        self.onSend();
    }
}

@end

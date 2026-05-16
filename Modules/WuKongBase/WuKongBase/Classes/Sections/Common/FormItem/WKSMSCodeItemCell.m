//
//  WKSMSCodeItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/10/26.
//

#import "WKSMSCodeItemCell.h"
#import "WKApp.h"
@implementation WKSMSCodeItemModel

- (Class)cell {
    return WKSMSCodeItemCell.class;
}

- (NSString *)sendBtnTitle {
    if(!_sendBtnTitle) {
        return @"发送";
    }
    return _sendBtnTitle;
}

@end

@interface WKSMSCodeItemCell ()

@property(nonatomic,strong) UITextField *codeInput;

@property(nonatomic,strong) UIButton *sendBtn;

@property(nonatomic,strong) UIView *splitView;

@property(nonatomic,strong) WKSMSCodeItemModel *model;

@end

@implementation WKSMSCodeItemCell


- (void)setupUI {
    [super setupUI];
    [self.contentView addSubview:self.codeInput];
    [self.contentView addSubview:self.sendBtn];
    [self.contentView addSubview:self.splitView];
}

- (void)refresh:(WKSMSCodeItemModel *)model {
    [super refresh:model];
    self.model = model;
    [self.sendBtn setTitle:model.sendBtnTitle forState:UIControlStateNormal];
    if(model.disable) {
        self.sendBtn.enabled = NO;
        [self.sendBtn setTitleColor:[WKApp shared].config.tipColor forState:UIControlStateNormal];
    }else{
        self.sendBtn.enabled = YES;
        [self.sendBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat codeInputLeft = 15.0f;
    self.codeInput.lim_width = self.contentView.lim_width - self.sendBtn.lim_width - codeInputLeft;
    self.codeInput.lim_height = self.contentView.lim_height;
    self.codeInput.lim_left = codeInputLeft;
    
    self.splitView.lim_left = self.codeInput.lim_right;
    self.splitView.lim_height = self.contentView.lim_height;
    
    self.sendBtn.lim_height = self.contentView.lim_height;
    self.sendBtn.lim_left = self.codeInput.lim_right;
    
}

- (UITextField *)codeInput {
    if(!_codeInput) {
        _codeInput = [[UITextField alloc] init];
        _codeInput.placeholder = @"请输入短信验证码";
        _codeInput.keyboardType = UIKeyboardTypeNumberPad;
        [_codeInput addTarget:self action:@selector(codeInputChanged) forControlEvents:UIControlEventEditingChanged];
    }
    return _codeInput;
}

-(void) codeInputChanged {
    if(self.model.onChange) {
        self.model.onChange(self.codeInput.text);
    }
}

- (UIButton *)sendBtn {
    if(!_sendBtn) {
        _sendBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 120.0f, 0.0f)];
        [_sendBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [[_sendBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_sendBtn addTarget:self action:@selector(sendPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _sendBtn;
}

-(void) sendPressed {
    if(self.model.onSend) {
        self.model.onSend();
    }
}

- (UIView *)splitView {
    if(!_splitView) {
        _splitView = [[UIView alloc] init];
        _splitView.lim_width = 1.0f;
        _splitView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    }
    return _splitView;
}

@end

//
//  WKChannelWebhookEditVC.m
//  WuKongBase
//

#import "WKChannelWebhookEditVC.h"
#import "WuKongBase.h"
#import "WKIncomingWebhook.h"
#import "WKIncomingWebhookManager.h"

#define WK_WEBHOOK_NAME_MAX 64
#define WK_WEBHOOK_AVATAR_MAX 255

@interface WKChannelWebhookEditVC ()<UITextFieldDelegate>
@property(nonatomic,strong) UIScrollView *scrollView;
@property(nonatomic,strong) UITextField *nameTF;
@property(nonatomic,strong) UITextField *avatarTF;
@property(nonatomic,strong) UILabel *memberPrefixHint;
@property(nonatomic,strong) UILabel *avatarHint;
@property(nonatomic,strong) UIButton *saveBtn;
@property(nonatomic,assign) BOOL saving;
@end

@implementation WKChannelWebhookEditVC

- (NSString *)langTitle {
    return self.editingWebhook ? LLang(@"编辑 Webhook") : LLang(@"新建 Webhook");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [self langTitle];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    self.rightView = self.saveBtn;

    [self.view addSubview:self.scrollView];
    [self buildForm];

    [self updateSaveBtnEnabled];
}

#pragma mark - UI

- (UIButton *)saveBtn {
    if (!_saveBtn) {
        _saveBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60.0f, 30.0f)];
        [_saveBtn setTitle:LLang(@"完成") forState:UIControlStateNormal];
        [_saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _saveBtn.backgroundColor = [WKApp shared].config.themeColor;
        _saveBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
        _saveBtn.layer.cornerRadius = 4.0f;
        _saveBtn.layer.masksToBounds = YES;
        [_saveBtn addTarget:self action:@selector(onSavePressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _saveBtn;
}

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:[self visibleRect]];
        _scrollView.backgroundColor = [WKApp shared].config.backgroundColor;
        _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
        _scrollView.alwaysBounceVertical = YES;
    }
    return _scrollView;
}

- (void)buildForm {
    CGFloat W = self.view.lim_width;
    CGFloat y = 16.0f;

    // 名称卡片
    UIView *nameWrap = [self fieldCardAtY:y height:72 width:W];
    UILabel *nameLbl = [self fieldLabel:LLang(@"名称")];
    nameLbl.frame = CGRectMake(16, 10, W - 64, 18);
    [nameWrap addSubview:nameLbl];

    self.nameTF = [self fieldTextField];
    self.nameTF.frame = CGRectMake(16, 32, W - 64, 30);
    self.nameTF.placeholder = LLang(@"如「构建通知」「监控告警」（可留空）");
    if (self.editingWebhook.name.length > 0) {
        self.nameTF.text = self.editingWebhook.name;
    }
    [self.nameTF addTarget:self action:@selector(onTextChanged) forControlEvents:UIControlEventEditingChanged];
    self.nameTF.delegate = self;
    [nameWrap addSubview:self.nameTF];
    [self.scrollView addSubview:nameWrap];
    y = CGRectGetMaxY(nameWrap.frame);

    // 成员前缀提示
    if (!self.isManagerOrCreator) {
        self.memberPrefixHint = [UILabel new];
        self.memberPrefixHint.frame = CGRectMake(20, y + 6, W - 40, 18);
        self.memberPrefixHint.font = [[WKApp shared].config appFontOfSize:12.0f];
        self.memberPrefixHint.textColor = [WKApp shared].config.tipColor;
        self.memberPrefixHint.text = LLang(@"普通成员创建的 Webhook 服务端会自动加 `Webhook-` 前缀。");
        self.memberPrefixHint.numberOfLines = 0;
        [self.memberPrefixHint sizeToFit];
        self.memberPrefixHint.lim_width = W - 40;
        [self.scrollView addSubview:self.memberPrefixHint];
        y = CGRectGetMaxY(self.memberPrefixHint.frame);
    }

    // 头像 URL（仅可管理者）
    if (self.isManagerOrCreator) {
        y += 12;
        UIView *avatarWrap = [self fieldCardAtY:y height:72 width:W];
        UILabel *avatarTitle = [self fieldLabel:LLang(@"头像 URL")];
        avatarTitle.frame = CGRectMake(16, 10, W - 64, 18);
        [avatarWrap addSubview:avatarTitle];

        self.avatarTF = [self fieldTextField];
        self.avatarTF.frame = CGRectMake(16, 32, W - 64, 30);
        self.avatarTF.placeholder = LLang(@"https://example.com/avatar.png");
        self.avatarTF.keyboardType = UIKeyboardTypeURL;
        self.avatarTF.autocapitalizationType = UITextAutocapitalizationTypeNone;
        if (self.editingWebhook.avatar.length > 0) {
            self.avatarTF.text = self.editingWebhook.avatar;
        }
        [self.avatarTF addTarget:self action:@selector(onTextChanged) forControlEvents:UIControlEventEditingChanged];
        self.avatarTF.delegate = self;
        [avatarWrap addSubview:self.avatarTF];
        [self.scrollView addSubview:avatarWrap];
        y = CGRectGetMaxY(avatarWrap.frame);

        self.avatarHint = [UILabel new];
        self.avatarHint.frame = CGRectMake(20, y + 6, W - 40, 18);
        self.avatarHint.font = [[WKApp shared].config appFontOfSize:12.0f];
        self.avatarHint.textColor = [WKApp shared].config.tipColor;
        self.avatarHint.text = LLang(@"留空使用默认头像。");
        self.avatarHint.numberOfLines = 0;
        [self.avatarHint sizeToFit];
        self.avatarHint.lim_width = W - 40;
        [self.scrollView addSubview:self.avatarHint];
        y = CGRectGetMaxY(self.avatarHint.frame);
    }

    self.scrollView.contentSize = CGSizeMake(W, y + 24);
}

- (UIView *)fieldCardAtY:(CGFloat)y height:(CGFloat)h width:(CGFloat)W {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(16, y, W - 32, h)];
    v.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    v.layer.cornerRadius = 10;
    v.layer.masksToBounds = YES;
    return v;
}

- (UILabel *)fieldLabel:(NSString *)text {
    UILabel *l = [UILabel new];
    l.font = [[WKApp shared].config appFontOfSize:13.0f];
    l.textColor = [WKApp shared].config.tipColor;
    l.text = text;
    return l;
}

- (UITextField *)fieldTextField {
    UITextField *tf = [UITextField new];
    tf.font = [[WKApp shared].config appFontOfSize:15.0f];
    tf.textColor = [WKApp shared].config.defaultTextColor;
    tf.borderStyle = UITextBorderStyleNone;
    tf.returnKeyType = UIReturnKeyDone;
    return tf;
}

#pragma mark - Logic

- (void)onTextChanged {
    // 长度限制兜底 —— UITextField 没法直接像 RN 那样 maxLength。
    if (self.nameTF.text.length > WK_WEBHOOK_NAME_MAX) {
        self.nameTF.text = [self.nameTF.text substringToIndex:WK_WEBHOOK_NAME_MAX];
    }
    if (self.avatarTF.text.length > WK_WEBHOOK_AVATAR_MAX) {
        self.avatarTF.text = [self.avatarTF.text substringToIndex:WK_WEBHOOK_AVATAR_MAX];
    }
    [self updateSaveBtnEnabled];
}

- (NSString *)trimmed:(NSString *)s {
    if (!s) return @"";
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)hasChange {
    if (!self.editingWebhook) return YES; // 新建态：留空也允许（服务端自动命名）
    NSString *n = [self trimmed:self.nameTF.text];
    NSString *a = [self trimmed:self.avatarTF.text];
    BOOL nameChanged = n.length > 0 && ![n isEqualToString:self.editingWebhook.name ?: @""];
    BOOL avatarChanged = self.isManagerOrCreator && ![a isEqualToString:self.editingWebhook.avatar ?: @""];
    return nameChanged || avatarChanged;
}

- (void)updateSaveBtnEnabled {
    BOOL canSave = [self hasChange] && !self.saving;
    self.saveBtn.enabled = canSave;
    self.saveBtn.alpha = canSave ? 1.0f : 0.5f;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Save

- (void)onSavePressed {
    if (self.saving) return;
    if (![self hasChange]) {
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
        return;
    }
    NSString *trimmedName = [self trimmed:self.nameTF.text];
    NSString *trimmedAvatar = [self trimmed:self.avatarTF.text];
    NSString *groupNo = self.channel.channelId;

    self.saving = YES;
    [self updateSaveBtnEnabled];
    [self.view showHUD];
    __weak typeof(self) weakSelf = self;

    if (self.editingWebhook) {
        // 编辑：仅发"有值且与原值不同"的字段
        NSString *nameParam = nil;
        if (trimmedName.length > 0 && ![trimmedName isEqualToString:self.editingWebhook.name ?: @""]) {
            nameParam = trimmedName;
        }
        NSString *avatarParam = nil;
        if (self.isManagerOrCreator && ![trimmedAvatar isEqualToString:self.editingWebhook.avatar ?: @""]) {
            avatarParam = trimmedAvatar; // 允许空串以清空
        }
        [[WKIncomingWebhookManager shared] updateWebhook:self.editingWebhook.webhookId
                                                   ofGroup:groupNo
                                                      name:nameParam
                                                    avatar:avatarParam
                                                    status:nil
                                                  complete:^(NSError * _Nullable error) {
            __strong typeof(weakSelf) self_ = weakSelf;
            if (!self_) return;
            self_.saving = NO;
            [self_.view hideHud];
            if (error) {
                [self_ updateSaveBtnEnabled];
                [self_.view showMsg:error.domain.length > 0 ? error.domain : LLang(@"保存失败")];
                return;
            }
            [self_.view showMsg:LLang(@"已保存")];
            if (self_.onUpdated) self_.onUpdated();
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }];
    } else {
        // 新建
        NSString *avatarParam = self.isManagerOrCreator && trimmedAvatar.length > 0 ? trimmedAvatar : nil;
        [[WKIncomingWebhookManager shared] createWebhookForGroup:groupNo
                                                            name:trimmedName.length > 0 ? trimmedName : nil
                                                          avatar:avatarParam
                                                        complete:^(WKIncomingWebhook * _Nullable webhook, NSError * _Nullable error) {
            __strong typeof(weakSelf) self_ = weakSelf;
            if (!self_) return;
            self_.saving = NO;
            [self_.view hideHud];
            if (error || !webhook) {
                [self_ updateSaveBtnEnabled];
                NSString *msg = error.domain.length > 0 ? error.domain : LLang(@"创建失败");
                [self_.view showMsg:msg];
                return;
            }
            // pop 自己 → 让上一层 VC 拉起 URL 弹窗（避免弹窗在自己被 pop 时被一起拆掉）
            if (self_.onCreated) self_.onCreated(webhook);
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }];
    }
}

@end

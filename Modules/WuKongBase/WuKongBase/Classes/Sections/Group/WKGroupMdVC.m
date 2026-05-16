#import "WKGroupMdVC.h"
#import "WKActionSheetView2.h"

#define WK_GROUPMD_MAX_BYTES 10240

static NSString * const kPlaceholderText = @"# 群组说明\n\n## 简介\n描述本群的用途和主题...\n\n## 规则\n1. 规则一\n2. 规则二\n\n## 常用链接\n- 链接一\n- 链接二\n";

@interface WKGroupMdVC () <UITextViewDelegate>

@property(nonatomic,strong) UITextView *textView;
@property(nonatomic,strong) UILabel *placeholderLbl;
@property(nonatomic,strong) UILabel *byteCountLbl;
@property(nonatomic,strong) UIButton *saveBtn;

@property(nonatomic,copy) NSString *originalContent;
@property(nonatomic,assign) NSInteger version;
@property(nonatomic,assign) BOOL saving;
@property(nonatomic,assign) BOOL loaded;

@end

@implementation WKGroupMdVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"GROUP.md";
    self.originalContent = @"";
    self.loaded = NO;

    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    [self.view addSubview:self.textView];
    [self.view addSubview:self.placeholderLbl];

    if(self.canEdit) {
        [self.view addSubview:self.byteCountLbl];
        self.rightView = self.saveBtn;
    }

    [self loadContent];
}

- (NSString *)langTitle {
    return @"GROUP.md";
}

#pragma mark - Subviews

- (UIButton *)saveBtn {
    if(!_saveBtn) {
        _saveBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60.0f, 30.0f)];
        [_saveBtn setTitle:LLang(@"保存") forState:UIControlStateNormal];
        [_saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _saveBtn.backgroundColor = [WKApp shared].config.themeColor;
        _saveBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
        _saveBtn.layer.cornerRadius = 4.0f;
        _saveBtn.layer.masksToBounds = YES;
        [_saveBtn addTarget:self action:@selector(onSavePressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _saveBtn;
}

- (UITextView *)textView {
    if(!_textView) {
        CGRect visibleRect = [self visibleRect];
        CGFloat bottomPadding = self.canEdit ? 50 : 10;
        _textView = [[UITextView alloc] initWithFrame:CGRectMake(16, visibleRect.origin.y + 10, self.view.lim_width - 32, visibleRect.size.height - bottomPadding)];
        _textView.font = [UIFont fontWithName:@"Menlo" size:14.0f] ?: [UIFont monospacedSystemFontOfSize:14.0f weight:UIFontWeightRegular];
        _textView.textColor = [WKApp shared].config.defaultTextColor;
        _textView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _textView.layer.cornerRadius = 8.0f;
        _textView.layer.masksToBounds = YES;
        _textView.textContainerInset = UIEdgeInsetsMake(12, 8, 12, 8);
        _textView.editable = self.canEdit;
        _textView.delegate = self;
        _textView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    }
    return _textView;
}

- (UILabel *)placeholderLbl {
    if(!_placeholderLbl) {
        _placeholderLbl = [[UILabel alloc] init];
        _placeholderLbl.numberOfLines = 0;
        _placeholderLbl.font = self.textView.font;
        _placeholderLbl.textColor = [WKApp shared].config.tipColor;
        _placeholderLbl.text = self.canEdit ? kPlaceholderText : LLang(@"暂未配置 GROUP.md");
        _placeholderLbl.textAlignment = NSTextAlignmentLeft;
        CGRect tvFrame = self.textView.frame;
        UIEdgeInsets inset = self.textView.textContainerInset;
        CGFloat lineFragmentPadding = self.textView.textContainer.lineFragmentPadding;
        CGFloat x = tvFrame.origin.x + inset.left + lineFragmentPadding;
        CGFloat y = tvFrame.origin.y + inset.top;
        CGFloat w = tvFrame.size.width - inset.left - inset.right - lineFragmentPadding * 2;
        _placeholderLbl.frame = CGRectMake(x, y, w, 0);
        [_placeholderLbl sizeToFit];
        _placeholderLbl.lim_width = w;
        _placeholderLbl.hidden = YES;
        _placeholderLbl.userInteractionEnabled = NO;
    }
    return _placeholderLbl;
}

- (UILabel *)byteCountLbl {
    if(!_byteCountLbl) {
        _byteCountLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, CGRectGetMaxY(self.textView.frame) + 8, self.view.lim_width - 32, 20)];
        _byteCountLbl.font = [UIFont systemFontOfSize:12.0f];
        _byteCountLbl.textColor = [WKApp shared].config.tipColor;
        _byteCountLbl.textAlignment = NSTextAlignmentRight;
    }
    return _byteCountLbl;
}

#pragma mark - Load Content

-(NSString*) apiBasePath {
    if (self.channel.channelType == WK_COMMUNITY_TOPIC) {
        NSRange sep = [self.channel.channelId rangeOfString:@"____"];
        if (sep.location != NSNotFound) {
            NSString *groupNo = [self.channel.channelId substringToIndex:sep.location];
            NSString *shortId = [self.channel.channelId substringFromIndex:sep.location + sep.length];
            return [NSString stringWithFormat:@"groups/%@/threads/%@/md", groupNo, shortId];
        }
    }
    return [NSString stringWithFormat:@"groups/%@/md", self.channel.channelId];
}

-(void) loadContent {
    MBProgressHUD *hud = [self.view showHUD];
    NSString *path = [self apiBasePath];
    [[WKAPIClient sharedClient] GET:path parameters:nil].then(^(NSDictionary *resp) {
        [hud hideAnimated:YES];
        NSString *c = resp[@"content"] ?: @"";
        self.originalContent = c;
        self.version = [resp[@"version"] integerValue];
        self.loaded = YES;
        [self refreshUI:c];
    }).catch(^(NSError *error) {
        [hud hideAnimated:YES];
        self.originalContent = @"";
        self.loaded = YES;
        [self refreshUI:@""];
    });
}

#pragma mark - Refresh UI

-(void) refreshUI:(NSString *)content {
    BOOL empty = (!content || [content isEqualToString:@""]);

    self.textView.text = content;
    self.placeholderLbl.hidden = !empty;
    [self updateByteCount];
}

-(void) updateByteCount {
    if(!self.canEdit) return;
    NSString *text = self.textView.text ?: @"";
    NSUInteger byteLen = [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    self.byteCountLbl.text = [NSString stringWithFormat:@"%lu / %d bytes", (unsigned long)byteLen, WK_GROUPMD_MAX_BYTES];
    self.byteCountLbl.textColor = (byteLen > WK_GROUPMD_MAX_BYTES) ? [UIColor redColor] : [WKApp shared].config.tipColor;
}

#pragma mark - Actions

-(void) onSavePressed {
    NSString *content = self.textView.text ?: @"";
    NSUInteger byteLen = [content lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if(byteLen > WK_GROUPMD_MAX_BYTES) {
        [self.view showMsg:LLang(@"内容超出大小限制")];
        return;
    }
    if(self.saving) return;
    self.saving = YES;
    self.saveBtn.enabled = NO;
    self.saveBtn.alpha = 0.6f;

    NSString *path = [self apiBasePath];
    [[WKAPIClient sharedClient] PUT:path parameters:@{@"content": content}].then(^(NSDictionary *resp) {
        self.saving = NO;
        self.saveBtn.enabled = YES;
        self.saveBtn.alpha = 1.0f;
        self.originalContent = content;
        self.version = [resp[@"version"] integerValue];
        [self updateChannelInfoExtra];
        [self.textView resignFirstResponder];
        [self.view showMsg:LLang(@"已保存")];
    }).catch(^(NSError *error) {
        self.saving = NO;
        self.saveBtn.enabled = YES;
        self.saveBtn.alpha = 1.0f;
        [self.view showMsg:LLang(@"保存失败")];
    });
}

-(void) updateChannelInfoExtra {
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:self.channel];
    if(info) {
        BOOL hasContent = self.originalContent && ![self.originalContent isEqualToString:@""];
        if (self.channel.channelType == WK_COMMUNITY_TOPIC) {
            info.extra[@"has_thread_md"] = @(hasContent);
            info.extra[@"thread_md_version"] = @(self.version);
        } else {
            info.extra[@"has_group_md"] = @(hasContent);
            info.extra[@"group_md_version"] = @(self.version);
        }
        [[WKSDK shared].channelManager updateChannelInfo:info];
    }
}

#pragma mark - UITextViewDelegate

-(void) textViewDidChange:(UITextView *)textView {
    BOOL empty = (!textView.text || [textView.text isEqualToString:@""]);
    self.placeholderLbl.hidden = !empty;
    [self updateByteCount];
}

#pragma mark - Keyboard

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

-(void) keyboardWillShow:(NSNotification*)noti {
    CGRect kbFrame = [noti.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat kbHeight = kbFrame.size.height;
    CGRect visibleRect = [self visibleRect];
    CGFloat bottom = visibleRect.origin.y + visibleRect.size.height - kbHeight - 30;
    [UIView animateWithDuration:0.25 animations:^{
        self.textView.frame = CGRectMake(16, visibleRect.origin.y + 10, self.view.lim_width - 32, bottom - visibleRect.origin.y - 10);
        self.byteCountLbl.frame = CGRectMake(16, CGRectGetMaxY(self.textView.frame) + 4, self.view.lim_width - 32, 20);
    }];
}

-(void) keyboardWillHide:(NSNotification*)noti {
    CGRect visibleRect = [self visibleRect];
    [UIView animateWithDuration:0.25 animations:^{
        self.textView.frame = CGRectMake(16, visibleRect.origin.y + 10, self.view.lim_width - 32, visibleRect.size.height - 50);
        self.byteCountLbl.frame = CGRectMake(16, CGRectGetMaxY(self.textView.frame) + 8, self.view.lim_width - 32, 20);
    }];
}

@end

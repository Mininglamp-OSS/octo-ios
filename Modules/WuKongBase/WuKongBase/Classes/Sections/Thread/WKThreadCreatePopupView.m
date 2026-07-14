//
//  WKThreadCreatePopupView.m
//  WuKongBase
//
//  - 见 .h 文件说明 -
//

#import "WKThreadCreatePopupView.h"
#import "WKThreadService.h"
#import "WKThreadModel.h"
#import "WKMessageModel.h"
#import "WKMessageBaseCell.h"
#import "WKMessageCell.h"
#import "WuKongBase.h"
#import "WKApp.h"
#import "NSString+WK.h"

@interface WKThreadCreatePopupView () <UITextFieldDelegate>

@property(nonatomic,strong) UIView *backdrop;
@property(nonatomic,strong) UIView *card;
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UIButton *closeBtn;

@property(nonatomic,strong) UIView *previewContainer;     ///< 浅灰底容器
@property(nonatomic,strong) UIScrollView *previewScroll;  ///< 内置滚动，让超大消息也可看
@property(nonatomic,strong) UITableViewCell *previewCell; ///< 直接复用聊天详情的消息 cell
@property(nonatomic,assign) CGFloat previewCellNaturalHeight;
@property(nonatomic,assign) CGFloat previewCellNaturalWidth;

@property(nonatomic,strong) UITextField *textField;
@property(nonatomic,strong) UIButton *cancelBtn;
@property(nonatomic,strong) UIButton *createBtn;

@property(nonatomic,copy)   NSString *groupNo;
@property(nonatomic,strong) WKMessageModel *sourceMessage;
@property(nonatomic,copy)   void(^onCreated)(WKThreadModel *);
@property(nonatomic,assign) BOOL creating;
@property(nonatomic,assign) CGFloat keyboardOffset;

@end

@implementation WKThreadCreatePopupView

#pragma mark - Public

+ (void)showWithGroupNo:(NSString *)groupNo
          sourceMessage:(WKMessageModel *)sourceMessage
            defaultName:(NSString *)defaultName
              onCreated:(void(^)(WKThreadModel *))onCreated {
    UIWindow *window = [self keyWindow];
    if (!window) return;

    WKThreadCreatePopupView *popup = [[self alloc] initWithGroupNo:groupNo
                                                     sourceMessage:sourceMessage
                                                       defaultName:defaultName
                                                         onCreated:onCreated];
    popup.frame = window.bounds;
    popup.alpha = 0;
    [window addSubview:popup];
    [popup setNeedsLayout];
    [popup layoutIfNeeded];

    popup.card.transform = CGAffineTransformMakeScale(0.92f, 0.92f);
    [UIView animateWithDuration:0.22 delay:0
         usingSpringWithDamping:0.9 initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        popup.alpha = 1.0;
        popup.card.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [popup.textField becomeFirstResponder];
        // 选区/digest 默认值进来时光标停在文末，方便用户改写
        UITextPosition *end = [popup.textField endOfDocument];
        popup.textField.selectedTextRange = [popup.textField textRangeFromPosition:end toPosition:end];
    }];
}

#pragma mark - Init

- (instancetype)initWithGroupNo:(NSString *)groupNo
                  sourceMessage:(WKMessageModel *)sourceMessage
                    defaultName:(NSString *)defaultName
                      onCreated:(void(^)(WKThreadModel *))onCreated {
    self = [super init];
    if (!self) return nil;

    _groupNo = [groupNo copy];
    _sourceMessage = sourceMessage;
    _onCreated = [onCreated copy];

    self.backgroundColor = [UIColor clearColor];

    [self buildUI];

    if (defaultName.length > 0) defaultName = [defaultName limitedStringForMaxBytesLength:100*2];
    if (defaultName.length > 0) _textField.text = defaultName;
    [self refreshCreateBtnEnabled];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onKeyboardWillChange:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI build

- (void)buildUI {
    BOOL isDark = ([WKApp shared].config.style == WKSystemStyleDark);

    // 背景遮罩 — 比长按菜单的半透明 0.08 略深，强调阻断式输入。
    _backdrop = [[UIView alloc] init];
    _backdrop.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4f];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBackdropTapped)];
    [_backdrop addGestureRecognizer:tap];
    [self addSubview:_backdrop];

    // 卡片 — 视觉参数对齐长按菜单卡片 (cornerR=14 / shadow 0.18 / radius 12)
    _card = [[UIView alloc] init];
    _card.backgroundColor = [WKApp shared].config.cellBackgroundColor
        ?: (isDark ? [UIColor colorWithRed:30/255.0 green:30/255.0 blue:30/255.0 alpha:1.0] : [UIColor whiteColor]);
    _card.layer.cornerRadius = 14.0f;
    _card.layer.shadowColor = [UIColor blackColor].CGColor;
    _card.layer.shadowOpacity = 0.18f;
    _card.layer.shadowRadius = 12.0f;
    _card.layer.shadowOffset = CGSizeMake(0, 4);
    [self addSubview:_card];

    // 标题
    _titleLbl = [[UILabel alloc] init];
    _titleLbl.text = LLang(@"创建子区");
    _titleLbl.font = [[WKApp shared].config appFontOfSizeSemibold:17.0f] ?: [UIFont boldSystemFontOfSize:17.0f];
    _titleLbl.textColor = [WKApp shared].config.defaultTextColor ?: [UIColor blackColor];
    [_card addSubview:_titleLbl];

    // ✕ 关闭
    _closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_closeBtn setTitle:@"✕" forState:UIControlStateNormal]; // ✕
    _closeBtn.titleLabel.font = [UIFont systemFontOfSize:18.0f];
    [_closeBtn setTitleColor:([WKApp shared].config.tipColor ?: [UIColor grayColor]) forState:UIControlStateNormal];
    [_closeBtn addTarget:self action:@selector(onClosePressed) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_closeBtn];

    // 预览区 — 仅长按消息触发时存在
    if (_sourceMessage) {
        _previewContainer = [[UIView alloc] init];
        _previewContainer.backgroundColor = isDark
            ? [UIColor colorWithRed:28/255.0 green:28/255.0 blue:30/255.0 alpha:1.0]
            : [UIColor colorWithRed:245/255.0 green:245/255.0 blue:247/255.0 alpha:1.0];
        _previewContainer.layer.cornerRadius = 10.0f;
        _previewContainer.layer.masksToBounds = YES;
        [_card addSubview:_previewContainer];

        _previewScroll = [[UIScrollView alloc] init];
        _previewScroll.showsVerticalScrollIndicator = NO;
        _previewScroll.showsHorizontalScrollIndicator = NO;
        // 关掉边界回弹 —— 预览只是静态展示，碰到边界时再继续拖会"软橡皮筋"反弹一下，
        // 在小卡片里观感很怪；超出范围也不需要"还有内容"的暗示。
        _previewScroll.bounces = NO;
        _previewScroll.alwaysBounceVertical = NO;
        _previewScroll.alwaysBounceHorizontal = NO;
        [_previewContainer addSubview:_previewScroll];

        [self buildPreviewCell];
    }

    // 输入框
    _textField = [[UITextField alloc] init];
    _textField.placeholder = LLang(@"子区名称 (最多100字)");
    _textField.font = [UIFont systemFontOfSize:15.0f];
    _textField.textColor = [WKApp shared].config.defaultTextColor ?: [UIColor blackColor];
    _textField.delegate = self;
    _textField.returnKeyType = UIReturnKeyDone;
    _textField.backgroundColor = isDark
        ? [UIColor colorWithRed:44/255.0 green:44/255.0 blue:46/255.0 alpha:1.0]
        : [UIColor colorWithRed:241/255.0 green:241/255.0 blue:243/255.0 alpha:1.0];
    _textField.layer.cornerRadius = 8.0f;
    _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 0)];
    _textField.leftView = leftPad;
    _textField.leftViewMode = UITextFieldViewModeAlways;
    [_textField addTarget:self action:@selector(onTextFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [_card addSubview:_textField];

    // 取消
    _cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_cancelBtn setTitle:LLang(@"取消") forState:UIControlStateNormal];
    _cancelBtn.titleLabel.font = [UIFont systemFontOfSize:16.0f];
    [_cancelBtn setTitleColor:([WKApp shared].config.defaultTextColor ?: [UIColor blackColor]) forState:UIControlStateNormal];
    _cancelBtn.backgroundColor = isDark
        ? [UIColor colorWithRed:58/255.0 green:58/255.0 blue:60/255.0 alpha:1.0]
        : [UIColor colorWithRed:241/255.0 green:241/255.0 blue:243/255.0 alpha:1.0];
    _cancelBtn.layer.cornerRadius = 22.0f;
    [_cancelBtn addTarget:self action:@selector(onClosePressed) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_cancelBtn];

    // 创建（主题色 fill）
    _createBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_createBtn setTitle:LLang(@"创建") forState:UIControlStateNormal];
    _createBtn.titleLabel.font = [UIFont systemFontOfSize:16.0f weight:UIFontWeightMedium];
    [_createBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_createBtn setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.7f] forState:UIControlStateDisabled];
    _createBtn.layer.cornerRadius = 22.0f;
    [_createBtn addTarget:self action:@selector(onCreatePressed) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_createBtn];
}

- (void)buildPreviewCell {
    // 走 message registry，保证不同 contentType 使用与聊天详情完全一致的 cell。
    Class cellClass = [[WKApp shared] getMessageCell:_sourceMessage.contentType];
    if (!cellClass) cellClass = [WKMessageCell class];

    UITableViewCell *cell = [[cellClass alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:@"WKThreadCreatePopupPreview"];
    cell.userInteractionEnabled = NO; // 静态预览，避免 nil conversationContext 引发的崩
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];

    // bind model（refresh: 在 WKMessageBaseCell 上）
    if ([cell isKindOfClass:[WKMessageBaseCell class]]) {
        [(WKMessageBaseCell *)cell refresh:_sourceMessage];
    }

    // 自然尺寸：cell 的 sizeForMessage 同时用作消息列表 row height（见
    // WKMessageListView._cachedHeightForMessage 行 2231-2233），width 用屏幕宽 ——
    // 这样 cell 内部 lim_width 与聊天详情下完全一致，bubble / 头像 / 昵称的相对位置
    // 不会与原页面错开。
    CGFloat naturalW = [UIScreen mainScreen].bounds.size.width;
    CGFloat naturalH = 60.0f;
    if ([cellClass respondsToSelector:@selector(sizeForMessage:)]) {
        CGSize s = [(id)cellClass sizeForMessage:_sourceMessage];
        if (s.height > 0) naturalH = s.height;
    }
    _previewCellNaturalWidth = naturalW;
    _previewCellNaturalHeight = naturalH;
    _previewCell = cell;

    cell.frame = CGRectMake(0, 0, naturalW, naturalH);
    [_previewScroll addSubview:cell];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    _backdrop.frame = self.bounds;

    CGFloat margin = 24.0f;
    CGFloat cardW = MIN(340.0f, self.bounds.size.width - margin * 2);

    CGFloat padH = 18.0f;
    CGFloat topPad = 16.0f;
    CGFloat sectionGap = 14.0f;
    CGFloat tfHeight = 44.0f;
    CGFloat btnHeight = 44.0f;
    CGFloat bottomPad = 16.0f;
    CGFloat titleHeight = 24.0f;

    CGFloat previewMaxH = 200.0f;
    CGFloat previewH = 0.0f;
    if (_previewContainer) {
        previewH = MIN(_previewCellNaturalHeight, previewMaxH);
    }

    CGFloat cardH = topPad + titleHeight;
    if (_previewContainer) cardH += sectionGap + previewH;
    cardH += sectionGap + tfHeight + sectionGap + btnHeight + bottomPad;

    CGFloat cardX = (self.bounds.size.width - cardW) / 2.0f;
    CGFloat cardY = (self.bounds.size.height - cardH) / 2.0f - _keyboardOffset;
    if (cardY < 24) cardY = 24;
    _card.bounds = CGRectMake(0, 0, cardW, cardH);
    _card.center = CGPointMake(cardX + cardW / 2.0f, cardY + cardH / 2.0f);

    // 标题 + ✕
    _titleLbl.frame = CGRectMake(padH, topPad, cardW - padH * 2 - 32, titleHeight);
    _closeBtn.frame = CGRectMake(cardW - padH - 24, topPad, 24, 24);

    CGFloat y = topPad + titleHeight + sectionGap;

    if (_previewContainer) {
        CGFloat innerW = cardW - padH * 2;
        _previewContainer.frame = CGRectMake(padH, y, innerW, previewH);
        _previewScroll.frame = _previewContainer.bounds;
        _previewScroll.contentSize = CGSizeMake(_previewCellNaturalWidth, _previewCellNaturalHeight);
        _previewCell.frame = CGRectMake(0, 0, _previewCellNaturalWidth, _previewCellNaturalHeight);
        [_previewCell setNeedsLayout];
        [_previewCell layoutIfNeeded];

        // 默认偏移：发出消息看右气泡，接收消息看左气泡 —— 与聊天详情视觉一致。
        CGFloat overflowX = MAX(0, _previewCellNaturalWidth - innerW);
        CGFloat overflowY = MAX(0, _previewCellNaturalHeight - previewH);
        CGFloat offsetX = _sourceMessage.isSend ? overflowX : 0.0f;
        _previewScroll.contentOffset = CGPointMake(offsetX, overflowY > 0 ? 0 : 0);

        y += previewH + sectionGap;
    }

    _textField.frame = CGRectMake(padH, y, cardW - padH * 2, tfHeight);
    y += tfHeight + sectionGap;

    CGFloat btnGap = 12.0f;
    CGFloat btnW = (cardW - padH * 2 - btnGap) / 2.0f;
    _cancelBtn.frame = CGRectMake(padH, y, btnW, btnHeight);
    _createBtn.frame = CGRectMake(padH + btnW + btnGap, y, btnW, btnHeight);

    UIColor *primary = [WKApp shared].config.themeColor
        ?: [UIColor colorWithRed:114/255.0 green:46/255.0 blue:209/255.0 alpha:1.0];
    _createBtn.backgroundColor = _createBtn.enabled ? primary : [primary colorWithAlphaComponent:0.4f];
}

#pragma mark - Actions

- (void)onBackdropTapped {
    // 点 backdrop 仅收起键盘 — 不直接关闭，避免误触丢失输入
    [_textField resignFirstResponder];
}

- (void)onClosePressed {
    [self dismissAnimated:YES];
}

- (void)onCreatePressed {
    if (_creating) return;
    NSString *name = [_textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) return;
    name = [name limitedStringForMaxBytesLength:100*2];

    _creating = YES;
    _createBtn.enabled = NO;
    [self setNeedsLayout];

    NSString *sourceMsgId = nil;
    NSDictionary *payload = nil;
    if (_sourceMessage && _sourceMessage.message.messageId > 0) {
        sourceMsgId = [NSString stringWithFormat:@"%llu", _sourceMessage.message.messageId];
        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        if (_sourceMessage.content.contentDict) {
            [p addEntriesFromDictionary:_sourceMessage.content.contentDict];
        }
        p[@"type"] = @(_sourceMessage.contentType);
        payload = p;
    }

    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] createThread:_groupNo
                                      name:name
                           sourceMessageId:sourceMsgId
                      sourceMessagePayload:payload].then(^(WKThreadModel *thread) {
        // join 成功 / 失败都视为整体成功（与原 alert 行为一致）—— 服务端已建好 thread，
        // 进群失败也不该卡住用户，让调用方自行决定是否继续 navigate。
        [[WKThreadService shared] joinThread:thread.shortId].then(^(id _) {
            [weakSelf finishCreatedWithThread:thread];
        }).catch(^(NSError *error) {
            [weakSelf finishCreatedWithThread:thread];
        });
    }).catch(^(NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.creating = NO;
        strongSelf.createBtn.enabled = YES;
        [strongSelf refreshCreateBtnEnabled];
        UIView *topView = [[WKNavigationManager shared] topViewController].view;
        [topView showMsg:(error.domain.length > 0 ? error.domain : LLang(@"创建失败"))];
    });
}

- (void)finishCreatedWithThread:(WKThreadModel *)thread {
    void(^cb)(WKThreadModel *) = self.onCreated;
    [self dismissAnimated:YES];
    if (cb) cb(thread);
}

- (void)onTextFieldChanged {
    NSString *t = _textField.text ?: @"";
    NSString *limited = [t limitedStringForMaxBytesLength:100*2];
    if (limited.length != t.length) _textField.text = limited;
    [self refreshCreateBtnEnabled];
}

- (void)refreshCreateBtnEnabled {
    NSString *t = [_textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL enabled = (t.length > 0) && !_creating;
    _createBtn.enabled = enabled;
    [self setNeedsLayout]; // 让 layoutSubviews 重算 createBtn 背景色
}

- (void)dismissAnimated:(BOOL)animated {
    [_textField resignFirstResponder];
    if (!animated) {
        [self removeFromSuperview];
        return;
    }
    [UIView animateWithDuration:0.18 animations:^{
        self.alpha = 0;
        self.card.transform = CGAffineTransformMakeScale(0.95f, 0.95f);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *next = [textField.text stringByReplacingCharactersInRange:range withString:string];
    NSString *limited = [next limitedStringForMaxBytesLength:100*2];
    if (limited.length != next.length) {
        textField.text = limited;
        [self refreshCreateBtnEnabled];
        return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (_createBtn.enabled) [self onCreatePressed];
    return YES;
}

#pragma mark - Keyboard

- (void)onKeyboardWillChange:(NSNotification *)note {
    CGRect endFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval dur = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [note.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    CGFloat windowH = self.bounds.size.height;
    CGFloat keyboardTop = endFrame.origin.y;
    if (keyboardTop >= windowH) {
        _keyboardOffset = 0;
    } else {
        // 把 card 上移到键盘顶部之上 12pt（保留呼吸感）
        CGFloat targetCardBottom = keyboardTop - 12.0f;
        CGFloat currentCardBottom = CGRectGetMaxY(_card.frame);
        CGFloat overflow = currentCardBottom - targetCardBottom;
        _keyboardOffset = MAX(0, _keyboardOffset + overflow);
    }

    [UIView animateWithDuration:MAX(dur, 0.2) delay:0
                        options:(curve << 16) animations:^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    } completion:nil];
}

#pragma mark - Window

+ (UIWindow *)keyWindow {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) return w;
            }
            keyWindow = ws.windows.firstObject;
            if (keyWindow) break;
        }
    }
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    return keyWindow;
}

@end

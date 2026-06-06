//
//  WKForwardConfirmPanel.m
//  WuKongBase
//

#import "WKForwardConfirmPanel.h"
#import <objc/runtime.h>
#import "WKConversationGroupThreadCell.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <WuKongBase/WuKongBase.h>

#define LLang(a) [a Localized:self]

static const NSInteger kOverlayTag = 88800;
static const NSInteger kPanelTag   = 88801;
static const NSInteger kMsgFieldTag = 88802;

@interface WKForwardConfirmPanel () <UIGestureRecognizerDelegate>
@property (nonatomic, copy) void(^onSend)(NSString * _Nullable extraText);
@property (nonatomic, strong, nullable) NSArray<NSDictionary *> *shareFileInfos;
@property (nonatomic, weak) UIView *overlay;
// 一次性 guard: dismissPanel 是 0.25s 淡出动画, removeFromSuperview 只在 completion
// 里执行; 期间 sendBtn 仍 enabled 仍 tappable, 下游 forwardMessage: 链路无 dedup —
// 一秒内双击同一次会话双发 (PR #32 R10 review)。
@property (nonatomic, assign) BOOL settled;
// 暗色蒙层 dismiss 手势; delegate 判 touch.view 在 panel 内时拒绝 fire, 避免
// 用户点 message UITextField / 按钮 / panel 内空白时被 dismissPanel 误关 panel
// (PR #32 R18 review: 否则附言输入框完全不可用)。
@property (nonatomic, weak) UITapGestureRecognizer *bgTap;
@end

@implementation WKForwardConfirmPanel

+ (void)showForChannel:(WKChannel *)channel
                  name:(nullable NSString *)name
               isGroup:(BOOL)isGroup
              isThread:(BOOL)isThread
        shareFileInfos:(nullable NSArray<NSDictionary *> *)shareFileInfos
                onSend:(void(^)(NSString * _Nullable extraText))onSend {
    WKForwardConfirmPanel *panel = [[WKForwardConfirmPanel alloc] init];
    panel.onSend = onSend;
    panel.shareFileInfos = shareFileInfos;
    [panel presentForChannel:channel name:name isGroup:isGroup isThread:isThread];
}

- (void)presentForChannel:(WKChannel *)channel name:(NSString *)name isGroup:(BOOL)isGroup isThread:(BOOL)isThread {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    CGFloat screenW = window.lim_width;
    CGFloat screenH = window.lim_height;

    // 半透明遮罩
    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    overlay.alpha = 0;
    overlay.tag = kOverlayTag;
    [window addSubview:overlay];
    self.overlay = overlay;

    // 持有自身，直到面板关闭
    objc_setAssociatedObject(overlay, "panelOwner", self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissPanel)];
    bgTap.delegate = self;
    [overlay addGestureRecognizer:bgTap];
    self.bgTap = bgTap;

    // 底部面板（高度稍后根据内容动态设置）
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = window.safeAreaInsets.bottom;
    }
    UIView *panel = [[UIView alloc] init];
    panel.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    panel.tag = kPanelTag;
    [overlay addSubview:panel];

    CGFloat pad = 20;
    CGFloat y = pad;

    // "发送给" 标题
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, screenW - pad*2, 22)];
    titleLbl.text = LLang(@"发送给");
    titleLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    titleLbl.textColor = [UIColor colorWithWhite:0.4 alpha:1];
    [panel addSubview:titleLbl];
    y += 30;

    // 目标行：图标/头像 + 名称
    UIView *targetRow = [[UIView alloc] initWithFrame:CGRectMake(pad, y, screenW - pad*2, 44)];
    [panel addSubview:targetRow];

    CGFloat iconLeft = 0;
    if (isGroup) {
        UILabel *hashLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 7, 30, 30)];
        hashLbl.text = @"#";
        hashLbl.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
        hashLbl.textColor = [UIColor colorWithRed:148/255.0 green:152/255.0 blue:168/255.0 alpha:1.0];
        hashLbl.textAlignment = NSTextAlignmentCenter;
        [targetRow addSubview:hashLbl];
        iconLeft = 34;
    } else if (isThread) {
        UIImageView *threadIcon = [[UIImageView alloc] initWithImage:[WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(20, 20) color:[UIColor colorWithRed:148/255.0 green:152/255.0 blue:168/255.0 alpha:1.0]]];
        threadIcon.frame = CGRectMake(4, 12, 20, 20);
        [targetRow addSubview:threadIcon];
        iconLeft = 30;
    } else {
        // 私聊头像
        WKUserAvatar *avatar = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 2, 40, 40)];
        WKChannelInfo *chInfo = [[WKSDK shared].channelManager getChannelInfo:channel];
        if (chInfo) {
            NSString *avatarURL = [WKAvatarUtil getAvatar:channel.channelId cacheKey:chInfo.avatarCacheKey];
            if (chInfo.logo.length > 0) avatarURL = [WKAvatarUtil getFullAvatarWIthPath:chInfo.logo];
            [avatar.avatarImgView sd_setImageWithURL:[NSURL URLWithString:avatarURL]
                                    placeholderImage:[WKApp.shared loadImage:@"Common/Index/DefaultAvatar" moduleID:@"WuKongBase"]];
        }
        [targetRow addSubview:avatar];
        iconLeft = 48;
    }

    UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(iconLeft, 0, targetRow.lim_width - iconLeft, 44)];
    nameLbl.text = name;
    nameLbl.font = [[WKApp shared].config appFontOfSizeMedium:16];
    nameLbl.textColor = [WKApp shared].config.defaultTextColor;
    [targetRow addSubview:nameLbl];
    y += 52;

    // 文件/链接预览卡片
    if (self.shareFileInfos.count > 0) {
        NSDictionary *fileInfo = self.shareFileInfos.firstObject;
        NSString *type = fileInfo[@"type"];
        NSString *fileName = fileInfo[@"fileName"] ?: @"";
        NSString *filePath = fileInfo[@"path"];

        CGFloat cardW = screenW * 0.62;
        CGFloat cardH = 66;
        CGFloat cardX = (screenW - cardW) / 2.0;

        // 链接分享：显示网页标题 + favicon
        if ([type isEqualToString:@"link"]) {
            NSString *linkTitle = fileInfo[@"title"] ?: @"";
            NSString *linkURL = fileInfo[@"url"] ?: @"";
            CGFloat linkPad = pad + 10;
            cardW = screenW - linkPad * 2;
            cardX = linkPad;
            cardH = 70;

            UIView *fileCard = [[UIView alloc] initWithFrame:CGRectMake(cardX, y, cardW, cardH)];
            fileCard.backgroundColor = [WKApp shared].config.backgroundColor;
            fileCard.layer.cornerRadius = 10;
            fileCard.layer.borderColor = [[UIColor grayColor] colorWithAlphaComponent:0.1].CGColor;
            fileCard.layer.borderWidth = 0.5;
            [panel addSubview:fileCard];

            // favicon（右侧）
            CGFloat iconSize = 36;
            UIImageView *faviconView = [[UIImageView alloc] initWithFrame:CGRectMake(cardW - iconSize - 14, (cardH - iconSize) / 2, iconSize, iconSize)];
            faviconView.contentMode = UIViewContentModeScaleAspectFit;
            faviconView.layer.cornerRadius = 6;
            faviconView.layer.masksToBounds = YES;
            faviconView.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.08];
            if (@available(iOS 13.0, *)) {
                UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIFontWeightRegular];
                faviconView.image = [[UIImage systemImageNamed:@"globe" withConfiguration:config] imageWithTintColor:[UIColor grayColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
            }
            [fileCard addSubview:faviconView];
            // 异步加载网站 favicon
            NSString *iconURL = fileInfo[@"icon"];
            NSURL *parsedURL = [NSURL URLWithString:linkURL];
            if (!iconURL && parsedURL.scheme && parsedURL.host) {
                iconURL = [NSString stringWithFormat:@"%@://%@/favicon.ico", parsedURL.scheme, parsedURL.host];
            }
            if (iconURL) {
                NSURL *faviconParsed = [NSURL URLWithString:iconURL];
                if (faviconParsed) {
                    // 5s timeout + 512KB cap (PR #32 R13/R15 review): 原来用
                    // NSData dataWithContentsOfURL: 无超时无 byte cap, 恶意 URL 可以
                    // 拖死面板 + 解码任意大小远程图片。
                    static const NSTimeInterval kFaviconTimeout = 5.0;
                    static const NSInteger kFaviconMaxBytes = 512 * 1024;
                    NSMutableURLRequest *favReq = [NSMutableURLRequest requestWithURL:faviconParsed
                                                                          cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                                      timeoutInterval:kFaviconTimeout];
                    NSURLSessionDataTask *favTask = [[NSURLSession sharedSession] dataTaskWithRequest:favReq
                                                                                    completionHandler:^(NSData * _Nullable data,
                                                                                                       NSURLResponse * _Nullable resp,
                                                                                                       NSError * _Nullable err) {
                        if (err || data.length == 0 || data.length > kFaviconMaxBytes) return;
                        UIImage *icon = [UIImage imageWithData:data];
                        if (!icon) return;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            faviconView.image = icon;
                            faviconView.backgroundColor = [UIColor clearColor];
                        });
                    }];
                    [favTask resume];
                }
            }

            // 标题
            CGFloat textW = cardW - iconSize - 40;
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 12, textW, 22)];
            titleLabel.text = linkTitle.length > 0 ? linkTitle : linkURL;
            titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            titleLabel.textColor = [WKApp shared].config.defaultTextColor;
            titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            [fileCard addSubview:titleLabel];

            // URL
            UILabel *urlLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 36, textW, 16)];
            urlLabel.text = linkURL;
            urlLabel.font = [UIFont systemFontOfSize:11];
            urlLabel.textColor = [UIColor grayColor];
            urlLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            [fileCard addSubview:urlLabel];

            y += cardH + 12;
        } else {
            // 文件/图片预览卡片（居中，宽约60%）
            UIView *fileCard = [[UIView alloc] initWithFrame:CGRectMake(cardX, y, cardW, cardH)];
            fileCard.backgroundColor = [WKApp shared].config.backgroundColor;
            fileCard.layer.cornerRadius = 8;
            fileCard.layer.borderColor = [[UIColor grayColor] colorWithAlphaComponent:0.12].CGColor;
            fileCard.layer.borderWidth = 0.5;
            [panel addSubview:fileCard];

            // 文件图标（右侧）
            CGFloat iconSize = 38;
            UIImageView *fileIconView = [[UIImageView alloc] initWithFrame:CGRectMake(cardW - iconSize - 12, (cardH - iconSize) / 2, iconSize, iconSize)];
            fileIconView.contentMode = UIViewContentModeScaleAspectFit;

            if ([type isEqualToString:@"image"] && filePath) {
                fileIconView.image = [UIImage imageWithContentsOfFile:filePath];
                fileIconView.contentMode = UIViewContentModeScaleAspectFill;
                fileIconView.clipsToBounds = YES;
                fileIconView.layer.cornerRadius = 4;
            } else {
                NSString *ext = [fileName pathExtension];
                fileIconView.image = [self fileIconForExtension:ext];
            }
            [fileCard addSubview:fileIconView];

            // 文件名
            CGFloat textW = cardW - iconSize - 34;
            UILabel *fl = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, textW, 36)];
            fl.text = fileName;
            fl.font = [UIFont systemFontOfSize:14];
            fl.textColor = [WKApp shared].config.defaultTextColor;
            fl.lineBreakMode = NSLineBreakByTruncatingMiddle;
            fl.numberOfLines = 2;
            [fileCard addSubview:fl];

            // 文件大小
            if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                unsigned long long size = [attrs fileSize];
                NSString *sizeStr;
                if (size < 1024) sizeStr = [NSString stringWithFormat:@"%lluB", size];
                else if (size < 1024*1024) sizeStr = [NSString stringWithFormat:@"%.1fKB", size/1024.0];
                else sizeStr = [NSString stringWithFormat:@"%.1fMB", size/1024.0/1024.0];
                UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(12, cardH - 22, textW, 16)];
                sl.text = sizeStr;
                sl.font = [UIFont systemFontOfSize:11];
                sl.textColor = [UIColor grayColor];
                [fileCard addSubview:sl];
            }
            y += cardH + 12;
        } // end else (file/image)
    }

    // 输入框
    UITextField *msgField = [[UITextField alloc] initWithFrame:CGRectMake(pad, y, screenW - pad*2, 40)];
    msgField.backgroundColor = [WKApp shared].config.backgroundColor;
    msgField.layer.cornerRadius = 6;
    msgField.placeholder = LLang(@"发消息");
    msgField.font = [UIFont systemFontOfSize:14];
    msgField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
    msgField.leftViewMode = UITextFieldViewModeAlways;
    msgField.tag = kMsgFieldTag;
    [panel addSubview:msgField];
    y += 50;

    // 按钮行
    CGFloat btnW = (screenW - pad*2 - 12) / 2;
    CGFloat btnH = 44;

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelBtn.frame = CGRectMake(pad, y, btnW, btnH);
    [cancelBtn setTitle:LLang(@"取消") forState:UIControlStateNormal];
    [cancelBtn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cancelBtn.backgroundColor = [WKApp shared].config.backgroundColor;
    cancelBtn.layer.cornerRadius = 8;
    [cancelBtn addTarget:self action:@selector(dismissPanel) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:cancelBtn];

    UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sendBtn.frame = CGRectMake(pad + btnW + 12, y, btnW, btnH);
    [sendBtn setTitle:LLang(@"发送") forState:UIControlStateNormal];
    [sendBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sendBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    sendBtn.backgroundColor = [UIColor colorWithRed:7/255.0 green:193/255.0 blue:96/255.0 alpha:1.0];
    sendBtn.layer.cornerRadius = 8;
    [sendBtn addTarget:self action:@selector(onSendTap) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:sendBtn];

    // 监听键盘
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    // 点击面板空白区域收键盘（按钮/输入框上不触发）
    UITapGestureRecognizer *panelTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    panelTap.delegate = self;
    [overlay addGestureRecognizer:panelTap];

    // 动态计算面板高度
    y += btnH + safeBottom + 16;
    CGFloat panelH = y;
    panel.frame = CGRectMake(0, screenH, screenW, panelH);

    // 圆角蒙版
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, screenW, panelH) byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:CGSizeMake(16, 16)];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;
    panel.layer.mask = maskLayer;

    // 弹出动画
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        overlay.alpha = 1;
        panel.frame = CGRectMake(0, screenH - panelH, screenW, panelH);
    } completion:nil];
}

- (void)dismissPanel {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];

    UIView *overlay = self.overlay;
    if (!overlay) return;
    [overlay endEditing:YES];
    UIView *panel = [overlay viewWithTag:kPanelTag];
    CGFloat screenH = overlay.lim_height;
    [UIView animateWithDuration:0.25 animations:^{
        overlay.alpha = 0;
        panel.frame = CGRectMake(0, screenH, panel.lim_width, panel.lim_height);
    } completion:^(BOOL finished) {
        // 移除 overlay 同时释放对自身的强引用
        objc_setAssociatedObject(overlay, "panelOwner", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [overlay removeFromSuperview];
    }];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // bgTap: 只允许点在 panel 外的暗色蒙层时触发 dismissPanel; 否则用户点
    // message UITextField / 按钮 / 文件卡 / 任何 panel 内空白都会关 panel,
    // 附言输入框完全不可用 (PR #32 R18 review)。
    if (gestureRecognizer == self.bgTap) {
        UIView *overlay = self.overlay;
        UIView *panel = [overlay viewWithTag:kPanelTag];
        if (panel && [touch.view isDescendantOfView:panel]) {
            return NO;
        }
        return YES;
    }
    // panelTap (dismissKeyboard): 点按钮/输入框时不收键盘 (原行为)
    if ([touch.view isKindOfClass:[UIButton class]] || [touch.view isKindOfClass:[UITextField class]]) {
        return NO;
    }
    return YES;
}

- (void)dismissKeyboard {
    [self.overlay endEditing:YES];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect kbFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIView *overlay = self.overlay;
    UIView *panel = [overlay viewWithTag:kPanelTag];
    if (!panel) return;
    CGFloat screenH = overlay.lim_height;
    CGFloat panelBottom = screenH - kbFrame.size.height;
    [UIView animateWithDuration:duration animations:^{
        panel.frame = CGRectMake(0, panelBottom - panel.lim_height, panel.lim_width, panel.lim_height);
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIView *overlay = self.overlay;
    UIView *panel = [overlay viewWithTag:kPanelTag];
    if (!panel) return;
    CGFloat screenH = overlay.lim_height;
    [UIView animateWithDuration:duration animations:^{
        panel.frame = CGRectMake(0, screenH - panel.lim_height, panel.lim_width, panel.lim_height);
    }];
}

- (void)onSendTap {
    if (self.settled) return;
    self.settled = YES;

    UIView *overlay = self.overlay;
    UITextField *msgField = [overlay viewWithTag:kMsgFieldTag];
    NSString *extraText = msgField.text;

    [self dismissPanel];

    if (self.onSend) {
        self.onSend(extraText);
    }
}

- (UIImage *)fileIconForExtension:(NSString *)ext {
    NSString *lowExt = [[ext lowercaseString] stringByReplacingOccurrencesOfString:@"." withString:@""];
    NSString *imageName = nil;
    if ([@[@"doc", @"docx", @"docm", @"rtf", @"odt", @"wps"] containsObject:lowExt]) imageName = @"FileType/FileWord";
    else if ([@[@"xls", @"xlsx", @"xlsm", @"csv", @"ods", @"et"] containsObject:lowExt]) imageName = @"FileType/FileExcel";
    else if ([lowExt isEqualToString:@"pdf"]) imageName = @"FileType/FilePDF";
    else if ([@[@"ppt", @"pptx", @"pptm", @"pps", @"ppsx"] containsObject:lowExt]) imageName = @"FileType/FilePPT";
    else if ([@[@"mp4", @"mov", @"avi", @"mkv", @"wmv", @"flv", @"webm"] containsObject:lowExt]) imageName = @"FileType/FileVideo";
    else if ([@[@"md", @"markdown"] containsObject:lowExt]) imageName = @"FileType/FileMarkdown";
    if (imageName) {
        UIImage *img = [[WKApp shared] loadImage:imageName moduleID:@"WuKongBase"];
        if (img) return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightRegular];
        UIImage *img = [UIImage systemImageNamed:@"doc.fill" withConfiguration:config];
        return [img imageWithTintColor:[UIColor systemBlueColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return nil;
}

@end

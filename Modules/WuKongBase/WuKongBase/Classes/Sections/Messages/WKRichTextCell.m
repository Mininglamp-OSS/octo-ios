//
//  WKRichTextCell.m
//  WuKongBase
//

#import "WKRichTextCell.h"
#import "WKRichTextContent.h"
#import "WKApp.h"
#import "UIView+WK.h"
#import "WKMessageTextView.h"
#import "NSMutableAttributedString+WK.h"
#import "WKRemoteImageAttachment.h"
#import "WKMatchToken.h"
#import "UIImage+WK.h"
#import "WKNavigationManager.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

// 按 block 处理的截断阈值（累计纯文本字符数），勿在 block 内部切断（契约 §5.2）。
static const NSInteger kRichTextTruncateThreshold = 10000;
static const CGFloat kViewFullTextBtnHeight = 36.0f;
// 内联图片的最大边长（避免单图撑满气泡）。
static const CGFloat kRichTextImageMaxLength = 220.0f;

@interface WKRichTextCell ()

@property(nonatomic,strong) WKMessageTextView *textLbl;
@property(nonatomic,strong) UIButton *viewFullTextBtn;

@end

@implementation WKRichTextCell

#pragma mark - 构建 attributed 正文（渲染与测量共用）

/// 把 blocks 渲染成 attributed string：text 块走 appendText，image 块走
/// appendRemoteImage（新建 WKRemoteImageToken，不走 entities offset 路线）。
/// 按 blocks 顺序穿插；超长按 block 截断，不切断图片块。
+ (NSMutableAttributedString*)attributedStringForMessage:(WKMessageModel*)model truncated:(BOOL*)truncated {
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
    attr.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    attr.textColor = model.isSend ? [WKApp shared].config.messageSendTextColor : [WKApp shared].config.messageRecvTextColor;

    if (![model.content isKindOfClass:[WKRichTextContent class]]) {
        if (truncated) { *truncated = NO; }
        return attr;
    }
    WKRichTextContent *content = (WKRichTextContent*)model.content;

    CGFloat maxWidth = [WKApp shared].config.messageContentMaxWidth;
    NSInteger accumulated = 0;
    BOOL didTruncate = NO;

    for (WKRichTextBlock *block in content.content) {
        // 按 block 截断：累计已过阈值则丢弃后续整块（含图片），不切碎单块。
        if (accumulated >= kRichTextTruncateThreshold) {
            didTruncate = YES;
            break;
        }

        if (block.type == WKRichTextBlockTypeImage) {
            if (block.url.length == 0) {
                continue;
            }
            // 图片独占一行，前后补换行，保证穿插清晰。
            if (attr.length > 0 && ![attr.string hasSuffix:@"\n"]) {
                [attr appendText:@"\n"];
            }
            CGSize displaySize = [[self class] displaySizeForBlock:block maxWidth:maxWidth];
            WKRemoteImageToken *token = [WKRemoteImageToken new];
            token.text = @"￼"; // object replacement char，承载 attachment
            token.url = block.url;
            token.size = displaySize;
            [attr appendRemoteImage:token];
            [attr appendText:@"\n"];
        } else if (block.type == WKRichTextBlockTypeText) {
            NSString *text = block.text ?: @"";
            if (text.length == 0) {
                continue;
            }
            // 文本可安全在 block 内截断（图片块绝不切断）：单个超长文本块只取
            // 剩余预算的前缀，其余丢弃并标记截断，走"查看全文"。
            NSInteger remaining = kRichTextTruncateThreshold - accumulated;
            if ((NSInteger)text.length > remaining) {
                text = [text substringToIndex:remaining];
                didTruncate = YES;
            }
            [attr appendText:text];
            accumulated += text.length;
        }
    }

    // 去掉末尾多余换行，避免气泡底部出现空行。
    while (attr.length > 0 && [attr.string hasSuffix:@"\n"]) {
        [attr deleteCharactersInRange:NSMakeRange(attr.length - 1, 1)];
    }

    if (truncated) { *truncated = didTruncate; }
    return attr;
}

+ (CGSize)displaySizeForBlock:(WKRichTextBlock*)block maxWidth:(CGFloat)maxWidth {
    CGFloat w = block.width > 0 ? block.width : 200.0f;
    CGFloat h = block.height > 0 ? block.height : 200.0f;
    CGFloat maxLength = MIN(maxWidth, kRichTextImageMaxLength);
    CGSize size = [UIImage lim_sizeWithImageOriginSize:CGSizeMake(w, h) maxLength:maxLength];
    if (size.width <= 0) { size.width = 80.0f; }
    if (size.height <= 0) { size.height = 80.0f; }
    return size;
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    CGFloat maxWidth = [WKApp shared].config.messageContentMaxWidth;
    BOOL truncated = NO;
    NSMutableAttributedString *attr = [[self class] attributedStringForMessage:model truncated:&truncated];
    CGSize size = [attr size:maxWidth];
    size.width = ceil(size.width) + 1.0f;
    size.height = ceil(size.height) + 1.0f;
    if (truncated) {
        size.height += kViewFullTextBtnHeight;
        size.width = MAX(size.width, maxWidth);
    }
    return size;
}

#pragma mark - UI

-(void) initUI {
    [super initUI];
    self.textLbl = [[WKMessageTextView alloc] init];
    [self.textLbl setFont:[[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize]];
    [self.messageContentView addSubview:self.textLbl];

    self.viewFullTextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.viewFullTextBtn setTitle:LLang(@"查看全文") forState:UIControlStateNormal];
    [self.viewFullTextBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    self.viewFullTextBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
    self.viewFullTextBtn.backgroundColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.1];
    self.viewFullTextBtn.layer.cornerRadius = 4.0f;
    self.viewFullTextBtn.layer.masksToBounds = YES;
    self.viewFullTextBtn.hidden = YES;
    [self.viewFullTextBtn addTarget:self action:@selector(viewFullTextTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.messageContentView addSubview:self.viewFullTextBtn];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    BOOL truncated = NO;
    NSMutableAttributedString *attr = [[self class] attributedStringForMessage:model truncated:&truncated];
    self.textLbl.attributedText = attr;
    self.viewFullTextBtn.hidden = !truncated;
    [self triggerImageDownloads:attr forModel:model];
}

/// 触发远程图片下载；下载完成后若 cell 仍展示同一消息，刷新重绘（显示尺寸固定，
/// 无需重算 cell 高度）。
- (void)triggerImageDownloads:(NSAttributedString*)attr forModel:(WKMessageModel*)model {
    if (attr.length == 0) { return; }
    __weak typeof(self) weakSelf = self;
    NSString *msgKey = model.clientMsgNo;
    [attr enumerateAttribute:NSAttachmentAttributeName
                     inRange:NSMakeRange(0, attr.length)
                     options:0
                  usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (![value isKindOfClass:[WKRemoteImageAttachment class]]) { return; }
        WKRemoteImageAttachment *attachment = (WKRemoteImageAttachment*)value;
        if (attachment.image) { return; }
        [attachment startDownload:^(UIImage *img) {
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) { return; }
                // 防止 cell 复用错位：仅当仍是同一消息才刷新。
                if (![strongSelf.messageModel.clientMsgNo isEqualToString:msgKey]) { return; }
                // 重新设置 attributedText 触发重新布局/重绘（attachment.image 已就绪）。
                strongSelf.textLbl.attributedText = strongSelf.textLbl.attributedText;
                [strongSelf.textLbl setNeedsDisplay];
            });
        }];
    }];
}

-(void) viewFullTextTapped {
    NSString *fullText = @"";
    if ([self.messageModel.content isKindOfClass:[WKRichTextContent class]]) {
        WKRichTextContent *content = (WKRichTextContent*)self.messageModel.content;
        // plain 优先；缺失时 conversationDigest 会遍历 content 兜底，勿丢字。
        fullText = content.plain.length > 0 ? content.plain : [content conversationDigest];
    }
    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = LLang(@"查看全文");
    vc.view.backgroundColor = [WKApp shared].config.backgroundColor;
    UITextView *textView = [[UITextView alloc] initWithFrame:vc.view.bounds];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.text = fullText;
    textView.editable = NO;
    textView.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    textView.textColor = [WKApp shared].config.defaultTextColor;
    textView.backgroundColor = [UIColor clearColor];
    textView.contentInset = UIEdgeInsetsMake(10, 10, 10, 10);
    [vc.view addSubview:textView];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(void) layoutSubviews {
    [super layoutSubviews];
    CGFloat contentW = self.messageContentView.lim_width;
    if (self.viewFullTextBtn.hidden) {
        self.textLbl.frame = CGRectMake(0, 0, contentW, self.messageContentView.lim_height);
    } else {
        CGFloat textH = self.messageContentView.lim_height - kViewFullTextBtnHeight;
        if (textH < 0) { textH = 0; }
        self.textLbl.frame = CGRectMake(0, 0, contentW, textH);
        self.viewFullTextBtn.frame = CGRectMake(0, textH, contentW, kViewFullTextBtnHeight);
    }
}

@end

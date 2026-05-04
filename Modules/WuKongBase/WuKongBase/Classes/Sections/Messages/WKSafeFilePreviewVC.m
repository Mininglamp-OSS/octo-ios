#import "WKSafeFilePreviewVC.h"
#import <PDFKit/PDFKit.h>
#import <WebKit/WebKit.h>
#import "WKApp.h"
#import "WKNavigationManager.h"
#import "WKRootNavigationController.h"
#include <libcmark_gfm/cmark-gfm.h>
#include <libcmark_gfm/cmark-gfm-core-extensions.h>

static UIWindow *_previewWindow = nil;
static UIWindow *_previousKeyWindow = nil;

@interface WKSafeFilePreviewVC ()
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, copy) NSString *fileTitle;
@property (nonatomic, strong) WKWebView *webView;
@end

@implementation WKSafeFilePreviewVC

#pragma mark - Init

- (instancetype)initWithFileURL:(NSURL *)fileURL title:(NSString *)title {
    self = [super init];
    if (self) {
        _fileURL = fileURL;
        _fileTitle = title ?: fileURL.lastPathComponent;
    }
    return self;
}

#pragma mark - 用独立 Window 展示，隔离 WebKit RunLoop

+ (void)showFilePreview:(NSURL *)fileURL title:(NSString *)title {
    if (_previewWindow) return;

    WKSafeFilePreviewVC *vc = [[WKSafeFilePreviewVC alloc] initWithFileURL:fileURL title:title];
    WKRootNavigationController *nav = [[WKRootNavigationController alloc] initWithRootViewController:vc];

    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
    }

    _previousKeyWindow = nil;
    for (UIWindow *w in scene.windows) {
        if (w.isKeyWindow) { _previousKeyWindow = w; break; }
    }

    UIWindow *window = scene
        ? [[UIWindow alloc] initWithWindowScene:scene]
        : [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.windowLevel = UIWindowLevelNormal + 1;
    window.rootViewController = nav;
    _previewWindow = window;

    // 从右侧滑入，模拟 push 动画
    window.frame = CGRectMake([UIScreen mainScreen].bounds.size.width, 0,
                              [UIScreen mainScreen].bounds.size.width,
                              [UIScreen mainScreen].bounds.size.height);
    window.hidden = NO;
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        window.frame = [UIScreen mainScreen].bounds;
    } completion:^(BOOL finished) {
        [window makeKeyAndVisible];
    }];
}

+ (void)dismissPreview {
    if (!_previewWindow) return;

    // 清理 WebKit
    UINavigationController *nav = (UINavigationController *)_previewWindow.rootViewController;
    if ([nav isKindOfClass:[UINavigationController class]]) {
        WKSafeFilePreviewVC *vc = (WKSafeFilePreviewVC *)nav.topViewController;
        if ([vc isKindOfClass:[WKSafeFilePreviewVC class]] && vc.webView) {
            [vc.webView stopLoading];
            [vc.webView removeFromSuperview];
            vc.webView = nil;
        }
    }

    // 向右滑出，模拟 pop 动画
    UIWindow *window = _previewWindow;
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        window.frame = CGRectMake([UIScreen mainScreen].bounds.size.width, 0,
                                  [UIScreen mainScreen].bounds.size.width,
                                  [UIScreen mainScreen].bounds.size.height);
    } completion:^(BOOL finished) {
        window.hidden = YES;
        window.rootViewController = nil;
        _previewWindow = nil;
        [_previousKeyWindow makeKeyAndVisible];
        _previousKeyWindow = nil;
    }];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.fileTitle;
    [self.navigationBar setShowBackButton:YES];

    // 分享按钮
    UIButton *shareBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    shareBtn.frame = CGRectMake(0, 0, 44, 44);
    [shareBtn setImage:[[UIImage systemImageNamed:@"square.and.arrow.up"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    shareBtn.tintColor = [WKApp shared].config.navBarButtonColor;
    [shareBtn addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
    self.navigationBar.rightView = shareBtn;

    NSString *ext = self.fileURL.pathExtension.lowercaseString;
    CGRect contentFrame = [self visibleRect];

    if ([ext isEqualToString:@"pdf"]) {
        [self setupPDFViewInFrame:contentFrame];
    } else {
        [self setupWebViewInFrame:contentFrame];
    }

    // 右滑手势返回
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(backPressed)];
    swipe.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipe];
}

- (void)backPressed {
    [WKSafeFilePreviewVC dismissPreview];
}

- (void)shareTapped {
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[self.fileURL] applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        avc.popoverPresentationController.sourceView = self.navigationBar.rightView;
    }
    [self presentViewController:avc animated:YES completion:nil];
}

#pragma mark - PDF (PDFKit, 完全无 WebKit)

- (void)setupPDFViewInFrame:(CGRect)frame {
    PDFView *pdfView = [[PDFView alloc] initWithFrame:frame];
    pdfView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    pdfView.autoScales = YES;
    BOOL isDark = [WKApp shared].config.style == WKSystemStyleDark;
    UIColor *bgColor = isDark ? [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1] : [UIColor whiteColor];
    pdfView.backgroundColor = bgColor;
    pdfView.document = [[PDFDocument alloc] initWithURL:self.fileURL];
    [self.view addSubview:pdfView];
}

#pragma mark - 其他文档 (WKWebView，在独立 Window 中与主导航完全隔离)

- (void)setupWebViewInFrame:(CGRect)frame {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.opaque = NO;
    BOOL isDark = [WKApp shared].config.style == WKSystemStyleDark;
    UIColor *bgColor = isDark ? [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1] : [UIColor whiteColor];
    self.webView.backgroundColor = bgColor;
    self.webView.scrollView.backgroundColor = bgColor;
    if (@available(iOS 13.0, *)) {
        self.webView.underPageBackgroundColor = bgColor;
    }

    NSString *ext = self.fileURL.pathExtension.lowercaseString;
    BOOL isMarkdown = [ext isEqualToString:@"md"] || [ext isEqualToString:@"markdown"];
    BOOL isPlainText = [ext isEqualToString:@"txt"] || [ext isEqualToString:@"log"] ||
        [ext isEqualToString:@"json"] || [ext isEqualToString:@"xml"] ||
        [ext isEqualToString:@"csv"] || [ext isEqualToString:@"yml"] ||
        [ext isEqualToString:@"yaml"] || [ext isEqualToString:@"ini"] ||
        [ext isEqualToString:@"conf"] || [ext isEqualToString:@"sh"] ||
        [ext isEqualToString:@"swift"] || [ext isEqualToString:@"java"] ||
        [ext isEqualToString:@"py"] || [ext isEqualToString:@"js"] ||
        [ext isEqualToString:@"ts"] || [ext isEqualToString:@"css"] ||
        [ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"];

    if (isMarkdown) {
        [self loadMarkdownFile];
    } else if (isPlainText) {
        [self loadPlainTextFile];
    } else {
        [self.webView loadFileURL:self.fileURL allowingReadAccessToURL:self.fileURL.URLByDeletingLastPathComponent];
    }
    [self.view addSubview:self.webView];
}

- (NSString *)markdownCSS {
    BOOL isDark = [WKApp shared].config.style == WKSystemStyleDark;
    if (isDark) {
        return @"body{font-family:-apple-system,system-ui;font-size:16px;line-height:1.6;padding:16px;max-width:100%;"
               @"background:#1c1c1e;color:#e5e5e7}"
               @"h1,h2,h3,h4{margin-top:1.2em;margin-bottom:0.4em}"
               @"h1{font-size:1.6em;border-bottom:1px solid #333;padding-bottom:6px}"
               @"h2{font-size:1.4em;border-bottom:1px solid #333;padding-bottom:4px}"
               @"h3{font-size:1.2em}"
               @"code{background:#2c2c2e;padding:2px 5px;border-radius:3px;font-family:Menlo,monospace;font-size:0.9em}"
               @"pre{background:#2c2c2e;padding:12px;border-radius:6px;overflow-x:auto}"
               @"pre code{background:none;padding:0}"
               @"blockquote{border-left:4px solid #555;margin:0;padding:4px 12px;color:#aaa}"
               @"table{border-collapse:collapse;width:100%}th,td{border:1px solid #444;padding:6px 10px;text-align:left}"
               @"th{background:#2c2c2e;font-weight:600}"
               @"img{max-width:100%}a{color:#58a6ff}";
    }
    return @"body{font-family:-apple-system,system-ui;font-size:16px;line-height:1.6;padding:16px;color:#333;max-width:100%;"
           @"background:#fff}"
           @"h1,h2,h3,h4{margin-top:1.2em;margin-bottom:0.4em}"
           @"h1{font-size:1.6em;border-bottom:1px solid #eee;padding-bottom:6px}"
           @"h2{font-size:1.4em;border-bottom:1px solid #eee;padding-bottom:4px}"
           @"h3{font-size:1.2em}"
           @"code{background:#f5f5f5;padding:2px 5px;border-radius:3px;font-family:Menlo,monospace;font-size:0.9em}"
           @"pre{background:#f5f5f5;padding:12px;border-radius:6px;overflow-x:auto}"
           @"pre code{background:none;padding:0}"
           @"blockquote{border-left:4px solid #ddd;margin:0;padding:4px 12px;color:#666}"
           @"table{border-collapse:collapse;width:100%}th,td{border:1px solid #ddd;padding:6px 10px;text-align:left}"
           @"th{background:#f5f5f5;font-weight:600}"
           @"img{max-width:100%}a{color:#0366d6}";
}

#pragma mark - Markdown (cmark-gfm 渲染)

- (void)loadMarkdownFile {
    NSData *data = [NSData dataWithContentsOfURL:self.fileURL];
    if (!data) return;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (!text) return;

    cmark_gfm_core_extensions_ensure_registered();
    cmark_parser *parser = cmark_parser_new(CMARK_OPT_DEFAULT);
    const char *extNames[] = {"strikethrough", "table", "autolink", "tagfilter"};
    for (int i = 0; i < 4; i++) {
        cmark_syntax_extension *ext = cmark_find_syntax_extension(extNames[i]);
        if (ext) cmark_parser_attach_syntax_extension(parser, ext);
    }
    const char *utf8 = [text UTF8String];
    cmark_parser_feed(parser, utf8, strlen(utf8));
    cmark_node *doc = cmark_parser_finish(parser);
    char *htmlCStr = cmark_render_html(doc, CMARK_OPT_DEFAULT, cmark_parser_get_syntax_extensions(parser));
    NSString *body = [NSString stringWithUTF8String:htmlCStr];
    free(htmlCStr);
    cmark_node_free(doc);
    cmark_parser_free(parser);

    NSString *html = [NSString stringWithFormat:
        @"<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
        @"<style>%@</style></head><body>%@</body></html>", [self markdownCSS], body];

    [self.webView loadHTMLString:html baseURL:self.fileURL.URLByDeletingLastPathComponent];
}

#pragma mark - 纯文本

- (void)loadPlainTextFile {
    NSData *data = [NSData dataWithContentsOfURL:self.fileURL];
    if (!data) return;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (!text) return;

    NSString *escaped = [text stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    BOOL isDark = [WKApp shared].config.style == WKSystemStyleDark;
    NSString *html = [NSString stringWithFormat:
        @"<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
        @"<style>body{font-family:-apple-system;font-size:15px;padding:12px;word-wrap:break-word;white-space:pre-wrap;"
        @"background:%@;color:%@}</style></head>"
        @"<body>%@</body></html>",
        isDark ? @"#1c1c1e" : @"#fff",
        isDark ? @"#e5e5e7" : @"#333",
        escaped];
    [self.webView loadHTMLString:html baseURL:self.fileURL.URLByDeletingLastPathComponent];
}

@end

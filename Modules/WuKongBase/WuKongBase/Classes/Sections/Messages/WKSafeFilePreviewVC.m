#import "WKSafeFilePreviewVC.h"
#import <PDFKit/PDFKit.h>
#import <WebKit/WebKit.h>
#import "WKApp.h"
#import "WKNavigationManager.h"
#import "WKRootNavigationController.h"

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
    pdfView.document = [[PDFDocument alloc] initWithURL:self.fileURL];
    [self.view addSubview:pdfView];
}

#pragma mark - 其他文档 (WKWebView，在独立 Window 中与主导航完全隔离)

- (void)setupWebViewInFrame:(CGRect)frame {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (@available(iOS 13.0, *)) {
        self.webView.backgroundColor = [UIColor systemBackgroundColor];
    }
    [self.webView loadFileURL:self.fileURL allowingReadAccessToURL:self.fileURL.URLByDeletingLastPathComponent];
    [self.view addSubview:self.webView];
}

@end

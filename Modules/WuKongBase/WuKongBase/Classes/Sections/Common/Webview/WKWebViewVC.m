//
//  WKWebViewVC.m
//  WuKongBase
//
//  Created by tt on 2020/4/3.
//

#import "WKWebViewVC.h"
#import "WKWebViewJavascriptBridge.h"
#import <WebKit/WebKit.h>
#import "WKCommonPlugin.h"
#import "WKJsonUtil.h"
#import "WKNavigationManager.h"
#import "WKMessageActionManager.h"
#import "WuKongBase.h"
#import "WKConversationVC.h"
#import "WKWebViewService.h"
#include <libcmark_gfm/cmark-gfm.h>
#include <libcmark_gfm/cmark-gfm-core-extensions.h>
@interface WKWebViewVC ()<WKUIDelegate,WKNavigationDelegate,UIScrollViewDelegate>

@property (nonatomic, strong) WKWebViewJavascriptBridge *bridge;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WKProcessPool *processPool;
@property (nonatomic, assign, getter=loadFinished) BOOL isLoadFinished;
@property(nonatomic,strong) UIProgressView *progressView;

@property (nonatomic, copy) NSURL* currentUrl; // 当前url地址

@property(nonatomic,strong) UIButton *moreBtn;

@property(nonatomic,assign) CGFloat lastContentOffsetY;

@property(nonatomic,assign) BOOL scrollIsUp; // 是否向上滚

@property(nonatomic,strong) UIView *bottomView;
@property(nonatomic,strong) UIButton *goBtn;
@property(nonatomic,strong) UIButton *gobackBtn;

@property(nonatomic,strong) WKWebViewService *webViewService;

// 服务器未声明 charset 的文本响应（如 .md），自行下载后用 cmark / loadHTMLString 渲染；
// 渲染失败或文件过大走原始加载的 URL 记录在此集合中，避免再次拦截造成死循环。
@property (nonatomic, strong) NSMutableSet<NSURL *> *bypassUTF8ReloadURLs;

// 当前正在下载的文本文件任务；用 task.progress KVO 驱动 progressView 显示下载进度。
@property (nonatomic, strong) NSURLSessionDataTask *currentTextDownloadTask;

@end

@implementation WKWebViewVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.webView];
    [self.view addSubview:self.progressView];
    
    self.navigationBar.rightView = self.moreBtn;
    
    self.webViewService.channel = self.channel;
    
    NSString *url = self.url.absoluteString;
    
    url = [url stringByRemovingPercentEncoding];
    
    if(url && ![url hasPrefix:@"http"]) {
        url = [NSString stringWithFormat:@"http://%@",url];
    }
    
    self.currentUrl = [NSURL URLWithString:url];
    
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
        cachePolicy:NSURLRequestReloadIgnoringCacheData
    timeoutInterval:(NSTimeInterval)10.0];
    
    [request setValue:[WKApp shared].config.langue forHTTPHeaderField:@"Accept-Language"];
    
    [self.webView loadRequest:request];
    [self.view addSubview:self.bottomView];
    
    [self showBottomView];
    
}

- (WKWebViewService *)webViewService {
    if(!_webViewService) {
        _webViewService = [[WKWebViewService alloc] init];
    }
    return _webViewService;
}

- (NSMutableSet<NSURL *> *)bypassUTF8ReloadURLs {
    if(!_bypassUTF8ReloadURLs) {
        _bypassUTF8ReloadURLs = [NSMutableSet set];
    }
    return _bypassUTF8ReloadURLs;
}

- (UIButton *)moreBtn {
    if(!_moreBtn) {
        _moreBtn = [[UIButton alloc] init];
        UIImage *img = [[self imageName:@"Common/Index/More"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [_moreBtn setImage:img forState:UIControlStateNormal];
        [_moreBtn setImage:img forState:UIControlStateHighlighted];
        [_moreBtn addTarget:self action:@selector(morePressed) forControlEvents:UIControlEventTouchUpInside];
        
        [_moreBtn setTintColor:WKApp.shared.config.navBarButtonColor];
    }
    return _moreBtn;
}

- (UIView *)bottomView {
    if(!_bottomView) {
        CGFloat bottomSafe = UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;
        _bottomView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.view.lim_height, self.view.lim_width, 50.0f + bottomSafe)];
        _bottomView.backgroundColor = WKApp.shared.config.navBackgroudColor;
//        _bottomView.alpha = 0.0f;
        
        [_bottomView addSubview:self.goBtn];
        
    
        [_bottomView addSubview:self.gobackBtn];
        
        CGFloat btwSpace = 60.0f;
        
        CGFloat contentWidth = self.goBtn.lim_width + btwSpace + self.gobackBtn.lim_width;
        self.gobackBtn.lim_left = _bottomView.lim_width/2.0f - contentWidth/2.0f;
        self.gobackBtn.lim_top = (_bottomView.lim_height-bottomSafe)/2.0f - self.gobackBtn.lim_height/2.0f + 10.0f;
        
        self.goBtn.lim_left = self.gobackBtn.lim_right + btwSpace;
        self.goBtn.lim_top = (_bottomView.lim_height-bottomSafe)/2.0f - self.goBtn.lim_height/2.0f + 10.0f;
    }
    return _bottomView;
}

- (UIButton *)gobackBtn {
    if(!_gobackBtn) {
        UIButton *gobackBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 28.0f, 28.0f)];
        UIImage *backImg = [LImage(@"Common/Index/Back") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [gobackBtn setImage:backImg forState:UIControlStateNormal];
        [gobackBtn setTintColor:WKApp.shared.config.navBarButtonColor];
        [gobackBtn addTarget:self action:@selector(gobackPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _gobackBtn = gobackBtn;
    }
    return _gobackBtn;
}

- (UIButton *)goBtn {
    if(!_goBtn) {
        UIButton *goBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 28.0f, 28.0f)];
        UIImage *goImg = [LImage(@"Common/Index/Go") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [goBtn setImage:goImg forState:UIControlStateNormal];
        [goBtn setTintColor:WKApp.shared.config.navBarButtonColor];
        [goBtn addTarget:self action:@selector(goPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _goBtn = goBtn;
    }
    return _goBtn;
}

-(void) goPressed {
    [self.webView goForward];
    [self checkGoAndGobackBtn];
}

-(void) gobackPressed {
    [self.webView goBack];
    [self checkGoAndGobackBtn];
}

-(void) morePressed {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *sheetView = [WKActionSheetView2 initWithTip:nil];
    [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"转发") onClick:^{
        WKTextContent *textContent = [[WKTextContent alloc] initWithContent:weakSelf.currentUrl.absoluteString];
        [[WKMessageActionManager shared] forwardContent:textContent complete:nil];
    }]];
    [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"复制") onClick:^{
        UIPasteboard* pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:weakSelf.currentUrl ?weakSelf.currentUrl.absoluteString: @""];
        [weakSelf.view showHUDWithHide:LLangW(@"已复制", weakSelf)];
    }]];
    [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"在浏览器中打开") onClick:^{
        [weakSelf openURLInSafari];
    }]];
    [sheetView show];
}

- (void)openURLInSafari
{

    if (self.currentUrl) {
        
        __weak typeof(self) weakSelf = self;
        
        NSString *invaildURLTip = LLang(@"无效的URL");

        NSURL* url = [NSURL URLWithString:self.currentUrl.absoluteString];
        if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0) {
            if ([[UIApplication sharedApplication]
                    respondsToSelector:@selector(openURL:
                                                     options:
                                           completionHandler:)]) {
                [[UIApplication sharedApplication] openURL:url
                    options:@{}
                    completionHandler:^(BOOL success) {
                        NSLog(@"Open %d", success);
                        if (!success) {
                            [weakSelf.view showHUDWithHide:invaildURLTip];
                        }
                    }];
            } else {
                bool can = [[UIApplication sharedApplication] canOpenURL:url];
                if (can) {
                    [[UIApplication sharedApplication] openURL:url];
                } else {
                    [weakSelf.view showHUDWithHide:invaildURLTip];
                }
            }
        } else {
            bool can = [[UIApplication sharedApplication] canOpenURL:url];
            if (can) {
                [[UIApplication sharedApplication] openURL:url];
            } else {
                [weakSelf.view showHUDWithHide:invaildURLTip];
            }
        }
    }
}

- (WKWebView *)webView {
    if(!_webView) {
        /*
          由于WKWebView在请求过程中用户可能退出界面销毁对象，当请求回调时由于接收处理对象不存在，造成Bad Access crash，所以可将WKProcessPool设为单例
         */
        static WKProcessPool *_sharedWKProcessPoolInstance = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _sharedWKProcessPoolInstance = [[WKProcessPool alloc] init];
        });
        self.processPool = _sharedWKProcessPoolInstance;
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        WKPreferences *preferences = [WKPreferences new];
        preferences.javaScriptCanOpenWindowsAutomatically = YES;
//        preferences.minimumFontSize = 40.0;
        configuration.preferences = preferences;
        configuration.processPool = self.processPool;
        _webView = [[WKWebView alloc] initWithFrame:CGRectMake(0.0f, self.navigationBar.lim_bottom, self.view.lim_width, self.view.lim_height - self.navigationBar.lim_bottom) configuration:configuration];
        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;
        _webView.scrollView.delegate = self;
        [_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
        [self addUserScript:_webView];
        
        [_webView addObserver:self forKeyPath:@"URL" options:NSKeyValueObservingOptionNew context:nil];
           /***/
        self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:_webView];
        [self.bridge setWebViewDelegate:self];
        self.webViewService.bridge = self.bridge;
        
        [self.webViewService registerHandlers];
        
    }
    return _webView;
}

- (UIProgressView *)progressView {
    if(!_progressView) {
        _progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, self.navigationBar.frame.size.height+self.navigationBar.frame.origin.y, [UIScreen mainScreen].bounds.size.width, 0)];
    }
    return _progressView;
}
// 计算wkWebView进度条
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self.webView && [keyPath isEqualToString:@"estimatedProgress"]) {
        CGFloat newprogress = [[change objectForKey:NSKeyValueChangeNewKey] doubleValue];
        self.progressView.alpha = 1.0f;
        [self.progressView setProgress:newprogress animated:YES];
        if (newprogress >= 1.0f) {
            [UIView animateWithDuration:0.3f
                                  delay:0.3f
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 self.progressView.alpha = 0.0f;
                             }
                             completion:^(BOOL finished) {
                                 [self.progressView setProgress:0 animated:NO];
                             }];
        }

    } else if(object == self.webView && [keyPath isEqualToString:@"URL"]) {
        [self checkGoAndGobackBtn];
    } else if (object == self.currentTextDownloadTask.progress && [keyPath isEqualToString:@"fractionCompleted"]) {
        // 文本/Markdown 下载进度。封顶 0.95，剩余 5% 留给本地 cmark 渲染和 loadHTMLString。
        CGFloat p = (CGFloat)self.currentTextDownloadTask.progress.fractionCompleted;
        if (p > 0.95f) p = 0.95f;
        if (p < 0.02f) p = 0.02f;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.alpha = 1.0f;
            [self.progressView setProgress:p animated:YES];
        });
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)dealloc
{
    [self stopObservingTextDownload];
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [self.webView removeObserver:self forKeyPath:@"URL"];
    self.webView.navigationDelegate = nil;
    self.webView.UIDelegate = nil;
    self.webView.scrollView.delegate = nil;
    [self.webView stopLoading];
}



-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}


-(void) checkGoAndGobackBtn {
    if([self.webView canGoBack]) {
        self.gobackBtn.enabled = YES;
        [self.gobackBtn setTintColor:WKApp.shared.config.navBarButtonColor];
    }else {
        self.gobackBtn.enabled = NO;
        [self.gobackBtn setTintColor:[UIColor grayColor]];
    }
    
    if([self.webView canGoForward]) {
        self.goBtn.enabled = YES;
        [self.goBtn setTintColor:WKApp.shared.config.navBarButtonColor];
    }else{
        self.goBtn.enabled = NO;
        [self.goBtn setTintColor:[UIColor grayColor]];
    }
}


#pragma mark - WKNavigationDelegate


- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self checkGoAndGobackBtn];
    
    __weak typeof(self) weakSelf = self;
    if(!self.title || [self.title isEqualToString:@""]) {
        [webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable resultStr, NSError * _Nullable error) {
            weakSelf.title = resultStr;
        }];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self checkGoAndGobackBtn];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    /*
      解决内存过大引起的白屏问题
     */
    [webView reload];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    
    /*
     //如果是302重定向请求，此处拦截带上cookie重新request
    NSMutableURLRequest *newRequest = [WKWebViewCookieMgr newRequest:navigationAction.request];
    [webView loadRequest:newRequest];
     */
    NSString* reqUrl = navigationAction.request.URL.absoluteString;
    if([reqUrl hasPrefix:@"http"] && ![self.url.host containsString:@"pgyer.com"]) { // pgyper 特殊处理下
        self.currentUrl = navigationAction.request.URL;
        //当前链接没有的话使用的是默认的URL地址
        if (!self.currentUrl) {
            self.currentUrl = self.url;
        }
    }

    //打开外部应用
   
    if (![reqUrl hasPrefix:@"http://"] && ![reqUrl hasPrefix:@"https://"]) {

        BOOL bSucc = [[UIApplication sharedApplication] openURL:navigationAction.request.URL];
        // bSucc是否成功调起
        if (bSucc) {
            [self.navigationController popViewControllerAnimated:NO];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}


// 服务器对 .md / .txt 等纯文本文档常常不带 charset，WKWebView 默认按 Latin-1
// 解码，导致中文乱码。此处仅在「主 frame + 纯文本类响应（非 text/html）+ 无 charset」
// 时拦截，自行下载后按 UTF-8 重灌；其他响应一律放行，不影响普通网页加载。
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSURLResponse *response = navigationResponse.response;
    NSURL *url = response.URL;

    if (!navigationResponse.isForMainFrame) {
        decisionHandler(WKNavigationResponsePolicyAllow);
        return;
    }
    if (url && [self.bypassUTF8ReloadURLs containsObject:url]) {
        decisionHandler(WKNavigationResponsePolicyAllow);
        return;
    }
    // 服务器自带 charset（或我们 loadData 重灌后），直接放行
    if (response.textEncodingName.length > 0) {
        decisionHandler(WKNavigationResponsePolicyAllow);
        return;
    }

    NSString *mime = (response.MIMEType ?: @"").lowercaseString;
    NSString *ext = url.pathExtension.lowercaseString ?: @"";
    static NSSet *textExts;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        textExts = [NSSet setWithArray:@[@"md", @"markdown", @"txt", @"log", @"csv", @"json", @"xml", @"yml", @"yaml"]];
    });
    // 关键：text/html / application/xhtml+xml 是网页，交给 WebKit 自己渲染，
    // 不能因为没声明 charset 就当成纯文本下载（否则登录跳转等页面会被 <pre> 包起来）。
    BOOL isHTML = [mime isEqualToString:@"text/html"] || [mime isEqualToString:@"application/xhtml+xml"];
    BOOL isText = !isHTML && ([mime hasPrefix:@"text/"] || [textExts containsObject:ext]);
    if (!isText) {
        decisionHandler(WKNavigationResponsePolicyAllow);
        return;
    }

    decisionHandler(WKNavigationResponsePolicyCancel);
    [self reloadWithUTF8ForResponse:response];
}

- (void)reloadWithUTF8ForResponse:(NSURLResponse *)response {
    static const long long kMaxBytes = 10 * 1024 * 1024; // 超过 10MB 不缓冲，回退原始加载
    NSURL *url = response.URL;
    if (!url) return;

    if (response.expectedContentLength > kMaxBytes) {
        [self.bypassUTF8ReloadURLs addObject:url];
        [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
        return;
    }

    NSString *ext = url.pathExtension.lowercaseString ?: @"";
    NSString *mime = response.MIMEType.lowercaseString ?: @"";
    BOOL isMarkdown = [ext isEqualToString:@"md"] || [ext isEqualToString:@"markdown"] || [mime containsString:@"markdown"];
    BOOL isCSV = [ext isEqualToString:@"csv"] || [mime containsString:@"csv"];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                   timeoutInterval:30.0];
    [req setValue:[WKApp shared].config.langue forHTTPHeaderField:@"Accept-Language"];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf stopObservingTextDownload];
            if (err || data.length == 0 || data.length > kMaxBytes) {
                [strongSelf.bypassUTF8ReloadURLs addObject:url];
                [strongSelf.webView loadRequest:[NSURLRequest requestWithURL:url]];
                return;
            }
            NSString *text = [strongSelf decodeTextFromData:data];
            NSString *html;
            if (isMarkdown) {
                html = [strongSelf htmlForMarkdown:text];
            } else if (isCSV) {
                html = [strongSelf htmlForCSV:text];
            } else {
                html = [strongSelf htmlForPlainText:text];
            }
            // baseURL 用文档目录，让相对路径的图片 / 资源能够正确解析
            NSURL *baseURL = [url URLByDeletingLastPathComponent];
            [strongSelf.webView loadHTMLString:html baseURL:baseURL];
        });
    }];

    [self stopObservingTextDownload];
    self.currentTextDownloadTask = task;
    [task.progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:nil];
    // 取消 navigation 后 estimatedProgress 可能仍在排队的 fade 动画，先打断，避免我们刚显示的进度被淡出
    [self.progressView.layer removeAllAnimations];
    self.progressView.alpha = 1.0f;
    [self.progressView setProgress:0.02f animated:NO]; // 给个初始可视进度，避免显示空白
    [task resume];
}

- (void)stopObservingTextDownload {
    if (_currentTextDownloadTask) {
        @try {
            [_currentTextDownloadTask.progress removeObserver:self forKeyPath:@"fractionCompleted"];
        } @catch (NSException *e) {}
        if (_currentTextDownloadTask.state == NSURLSessionTaskStateRunning) {
            [_currentTextDownloadTask cancel];
        }
        _currentTextDownloadTask = nil;
    }
}

#pragma mark - Text 渲染

// 拷贝自 WKSafeFilePreviewVC.decodeTextFromData:，保持同一套编码嗅探逻辑。
// 关键顺序：
//   1. UTF-32 BOM 必须在 UTF-16 BOM 之前判定（UTF-32 LE BOM 前两字节与 UTF-16 LE BOM 重合）
//   2. ISO-2022-* 优先于 UTF-8（UTF-8 严格解码 ISO-2022 不会失败，但输出乱码）
//   3. CJK 启发式放在 GB18030 / Big5 直试之前（GB18030 过度宽容会把 Big5 当成假中文）
- (NSString *)decodeTextFromData:(NSData *)data {
    if (data.length == 0) return @"";
    const unsigned char *bytes = data.bytes;
    NSUInteger len = data.length;

    if (len >= 4 && bytes[0] == 0xFF && bytes[1] == 0xFE && bytes[2] == 0x00 && bytes[3] == 0x00) {
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF32LittleEndianStringEncoding];
        if (s) return s;
    }
    if (len >= 4 && bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0xFE && bytes[3] == 0xFF) {
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF32BigEndianStringEncoding];
        if (s) return s;
    }
    if (len >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        NSString *s = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(3, len - 3)]
                                            encoding:NSUTF8StringEncoding];
        if (s) return s;
    }
    if (len >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF16LittleEndianStringEncoding];
        if (s) return s;
    }
    if (len >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF16BigEndianStringEncoding];
        if (s) return s;
    }

    NSUInteger sniffLen = MIN(len, (NSUInteger)4096);
    BOOL maybeISO2022 = NO;
    for (NSUInteger i = 0; i + 1 < sniffLen; i++) {
        if (bytes[i] == 0x1B) {
            unsigned char next = bytes[i + 1];
            if (next == '$' || next == '(' || next == ')') { maybeISO2022 = YES; break; }
        }
    }
    if (maybeISO2022) {
        NSStringEncoding candidates[] = {
            CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_CN),
            CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP),
            CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_KR),
        };
        for (int i = 0; i < 3; i++) {
            NSString *s = [[NSString alloc] initWithData:data encoding:candidates[i]];
            if (s) return s;
        }
    }

    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (s) return s;

    NSArray<NSNumber *> *suggested = @[
        @(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)),
        @(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)),
        @(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_CN)),
        @(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP)),
        @(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_KR)),
        @(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingShiftJIS)),
        @(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_JP)),
        @(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR)),
        @(NSUTF16LittleEndianStringEncoding),
        @(NSUTF16BigEndianStringEncoding),
        @(NSUTF32LittleEndianStringEncoding),
        @(NSUTF32BigEndianStringEncoding),
    ];
    NSDictionary *opts = @{
        NSStringEncodingDetectionSuggestedEncodingsKey: suggested,
        NSStringEncodingDetectionUseOnlySuggestedEncodingsKey: @YES,
    };
    NSString *detected = nil;
    NSStringEncoding guessed = [NSString stringEncodingForData:data
                                               encodingOptions:opts
                                               convertedString:&detected
                                           usedLossyConversion:NULL];
    if (guessed != 0 && detected.length > 0) return detected;

    NSStringEncoding gb18030 = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    s = [[NSString alloc] initWithData:data encoding:gb18030];
    if (s) return s;
    NSStringEncoding big5 = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5);
    s = [[NSString alloc] initWithData:data encoding:big5];
    if (s) return s;

    return [[NSString alloc] initWithBytes:data.bytes
                                    length:data.length
                                  encoding:NSUTF8StringEncoding] ?: @"";
}

- (NSString *)htmlForMarkdown:(NSString *)text {
    if (text.length == 0) return [self htmlForPlainText:@""];

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
    NSString *body = [NSString stringWithUTF8String:htmlCStr] ?: @"";
    free(htmlCStr);
    cmark_node_free(doc);
    cmark_parser_free(parser);

    return [NSString stringWithFormat:
        @"<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
        @"<style>%@</style></head><body>%@</body></html>", [self markdownCSS], body];
}

- (NSString *)htmlForPlainText:(NSString *)text {
    NSString *escaped = [self escapeHTML:text];
    BOOL isDark = [WKApp shared].config.style == WKSystemStyleDark;
    return [NSString stringWithFormat:
        @"<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
        @"<style>body{font-family:-apple-system;font-size:15px;padding:12px;word-wrap:break-word;white-space:pre-wrap;"
        @"background:%@;color:%@}</style></head>"
        @"<body>%@</body></html>",
        isDark ? @"#1c1c1e" : @"#fff",
        isDark ? @"#e5e5e7" : @"#333",
        escaped];
}

- (NSString *)escapeHTML:(NSString *)s {
    if (s.length == 0) return @"";
    NSMutableString *m = [s mutableCopy];
    [m replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, m.length)];
    return m;
}

// 把 CSV 渲染成可横向滚动的表格。首行视作表头并 sticky。
- (NSString *)htmlForCSV:(NSString *)text {
    NSArray<NSArray<NSString *> *> *rows = [self parseCSV:text];
    if (rows.count == 0) return [self htmlForPlainText:text];

    BOOL isDark = [WKApp shared].config.style == WKSystemStyleDark;
    NSString *bg = isDark ? @"#1c1c1e" : @"#fff";
    NSString *fg = isDark ? @"#e5e5e7" : @"#333";
    NSString *border = isDark ? @"#3a3a3c" : @"#e5e5e7";
    NSString *headerBg = isDark ? @"#2c2c2e" : @"#f5f5f7";
    NSString *altBg = isDark ? @"#242426" : @"#fafafa";

    NSUInteger maxCols = 0;
    for (NSArray *r in rows) if (r.count > maxCols) maxCols = r.count;

    NSMutableString *html = [NSMutableString stringWithCapacity:rows.count * 64];
    [html appendFormat:
        @"<html><head><meta charset='utf-8'>"
        @"<meta name='viewport' content='width=device-width,initial-scale=1'>"
        @"<style>"
        @"html,body{margin:0;padding:0;height:100%%;background:%@;color:%@;"
        @"font-family:-apple-system,system-ui;font-size:14px}"
        @".wrap{overflow:auto;-webkit-overflow-scrolling:touch;height:100%%}"
        @"table{border-collapse:collapse;width:max-content;min-width:100%%}"
        @"th,td{padding:8px 12px;border:1px solid %@;white-space:nowrap;"
        @"vertical-align:top;text-align:left;max-width:480px;overflow:hidden;text-overflow:ellipsis}"
        @"th{background:%@;font-weight:600;position:sticky;top:0;z-index:1}"
        @"tbody tr:nth-child(even){background:%@}"
        @"td{user-select:text;-webkit-user-select:text}"
        @"</style></head><body><div class='wrap'><table>",
        bg, fg, border, headerBg, altBg];

    NSArray<NSString *> *header = rows.firstObject;
    [html appendString:@"<thead><tr>"];
    for (NSUInteger i = 0; i < maxCols; i++) {
        NSString *cell = i < header.count ? header[i] : @"";
        [html appendFormat:@"<th>%@</th>", [self escapeHTML:cell]];
    }
    [html appendString:@"</tr></thead><tbody>"];

    for (NSUInteger r = 1; r < rows.count; r++) {
        NSArray<NSString *> *row = rows[r];
        [html appendString:@"<tr>"];
        for (NSUInteger i = 0; i < maxCols; i++) {
            NSString *cell = i < row.count ? row[i] : @"";
            [html appendFormat:@"<td>%@</td>", [self escapeHTML:cell]];
        }
        [html appendString:@"</tr>"];
    }
    [html appendString:@"</tbody></table></div></body></html>"];
    return html;
}

// RFC4180-兼容的 CSV 解析。支持：引号包围字段（含字段内逗号/换行）、""转义引号、CRLF/LF 行尾。
// 不处理变种分隔符（如 TSV/分号），保持职责单一。
- (NSArray<NSArray<NSString *> *> *)parseCSV:(NSString *)text {
    if (text.length == 0) return @[];
    NSMutableArray<NSArray<NSString *> *> *rows = [NSMutableArray array];
    NSMutableArray<NSString *> *row = [NSMutableArray array];
    NSMutableString *field = [NSMutableString string];
    BOOL inQuotes = NO;
    NSUInteger len = text.length;

    // 一次性把 UTF-16 unit 拷到栈/堆 buffer，避免逐字符调用 characterAtIndex: 的开销
    unichar *buf = (unichar *)malloc(sizeof(unichar) * len);
    if (!buf) return @[];
    [text getCharacters:buf range:NSMakeRange(0, len)];

    void (^commitField)(void) = ^{
        [row addObject:[field copy]];
        [field setString:@""];
    };
    void (^commitRow)(void) = ^{
        // 跳过完全空白行（只有一个空 field 的情况）
        if (!(row.count == 1 && [row[0] length] == 0)) {
            [rows addObject:[row copy]];
        }
        [row removeAllObjects];
    };

    for (NSUInteger i = 0; i < len; i++) {
        unichar c = buf[i];
        if (inQuotes) {
            if (c == '"') {
                if (i + 1 < len && buf[i + 1] == '"') {
                    [field appendString:@"\""];
                    i++;
                } else {
                    inQuotes = NO;
                }
            } else {
                [field appendFormat:@"%C", c];
            }
        } else {
            if (c == '"') {
                inQuotes = YES;
            } else if (c == ',') {
                commitField();
            } else if (c == '\r' || c == '\n') {
                if (c == '\r' && i + 1 < len && buf[i + 1] == '\n') i++;
                commitField();
                commitRow();
            } else {
                [field appendFormat:@"%C", c];
            }
        }
    }
    // 最后没有换行结尾时收尾
    if (field.length > 0 || row.count > 0) {
        commitField();
        commitRow();
    }
    free(buf);
    return rows;
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


- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    
//    //解决window.alert() 时 completionHandler 没有被调用导致崩溃问题
//    if (!self.isLoadFinished) {
//        completionHandler();
//        return;
//    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { completionHandler(); }]];
    if (self)
        [self presentViewController:alertController animated:YES completion:^{}];
    else
        completionHandler();
}


- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler{

    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *card = [[NSURLCredential alloc]initWithTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, card);
    } else {
        // 其他认证方式走默认处理，必须调用 completionHandler 否则 WebKit 会崩溃
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }

}



/**
 通过·document.cookie·设置cookie解决后续页面(同域)Ajax、iframe请求的cookie问题
 @param webView wkwebview
 */
- (void)addUserScript:(WKWebView *)webView {
//    NSString *js = [WKWebViewCookieMgr clientCookieScripts];
//    if (!js) return;
//    WKUserScript *jsscript = [[WKUserScript alloc]initWithSource:js
//                                                   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
//                                                forMainFrameOnly:NO];
//    [webView.configuration.userContentController addUserScript:jsscript];
}

#pragma mark -- UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.lastContentOffsetY = scrollView.contentOffset.y;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
    if(![self.webView canGoBack] && ![self.webView canGoForward]) {
        return;
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(scrollViewDidEnd) withObject:nil afterDelay:0.3];
    
    if (scrollView.contentOffset.y < self.lastContentOffsetY ){ //向上
        CGFloat offset = self.lastContentOffsetY - scrollView.contentOffset.y;
        NSLog(@"上滑--->%0.2f",offset);
        self.scrollIsUp = true;
        
        if(self.bottomView.lim_top<=self.view.lim_height - self.bottomView.lim_height) { // 完全显示了
            return;
        }
        
        if(offset <= self.bottomView.lim_height) {
            self.bottomView.lim_top = self.view.lim_height - offset;
        }else{
            self.bottomView.lim_top = self.view.lim_height - self.bottomView.lim_height;
        }
        
    } else if (scrollView.contentOffset.y > self.lastContentOffsetY ){ //向下
        self.scrollIsUp = false;
        CGFloat offset = self.lastContentOffsetY - scrollView.contentOffset.y;
        NSLog(@"下滑-->%0.2f",offset);
        if(self.bottomView.lim_top>=self.view.lim_height) { // 隐藏了
            return;
        }
        
        if(-offset <= self.bottomView.lim_height) {
            self.bottomView.lim_top = self.view.lim_height - (self.bottomView.lim_height + offset);
        }else{
            self.bottomView.lim_top = self.view.lim_height;
        }
    }
    [self resetWebViewHeight];
}

-(void) scrollViewDidEnd {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    [self showBottomView];
   
   
}

-(void) showBottomView {
    [UIView animateWithDuration:WKApp.shared.config.defaultAnimationDuration animations:^{
        if(self.scrollIsUp) {
            self.bottomView.lim_top = self.view.lim_height - self.bottomView.lim_height;
        }else{
            self.bottomView.lim_top = self.view.lim_height;
        }
        [self resetWebViewHeight];
    }];
}

-(void) resetWebViewHeight {
//    CGFloat safeBottom = self.view.window.safeAreaInsets.bottom;
    self.webView.lim_height = self.bottomView.lim_top - self.navigationBar.lim_bottom;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
}


@end

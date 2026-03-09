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
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)dealloc
{
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
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
    NSLog(@"%@",navigationAction.request.allHTTPHeaderFields);
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
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            completionHandler(NSURLSessionAuthChallengeUseCredential,card);
        });
        
        
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

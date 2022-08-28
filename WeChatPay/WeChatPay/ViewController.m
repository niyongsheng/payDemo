//
//  ViewController.m
//  WeChatPay
//
//  Created by niyongsheng on 2022/8/26.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>

#define iphoneX ({ \
    BOOL iPhoneX = NO; \
    if (@available(iOS 11.0, *)) { \
        if ([UIApplication sharedApplication].windows[0].safeAreaInsets.bottom > 0) { \
            iPhoneX = YES; \
        } \
    } \
    iPhoneX; \
})

#define NavHeight (iphoneX ? 88.0 : 64.0)
#define StatusBarHeight (iphoneX ? 44.0 : 20.0)
#define MenuBarHeight (iphoneX?34:0)

#define ScreenH [UIScreen mainScreen].bounds.size.height
#define ScreenW [UIScreen mainScreen].bounds.size.width

#define XDX_URL_TIMEOUT 30

static const NSString *CompanyFirstDomainByWeChatRegister = @"restaurant.pengyuns.com";

@interface ViewController ()
<
WKUIDelegate,
WKNavigationDelegate
>
@property(nonatomic, strong)WKWebView *webView;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic,assign) double lastProgress;
@end

@implementation ViewController

- (NSString *)urlString {
    if (!_urlString) {
        _urlString = @"http://1.15.37.77:8222/#/";
    }
    return _urlString;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addSubview:self.webView];
}

- (WKWebView *)webView{
    if (!_webView) {
        // 适配文字大小
        NSString *jScript = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";
        WKUserScript *wkUScript = [[WKUserScript alloc] initWithSource:jScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        WKUserContentController *wkUController = [[WKUserContentController alloc] init];
        [wkUController addUserScript:wkUScript];
        
        WKWebViewConfiguration *wkWebConfig = [[WKWebViewConfiguration alloc] init];
        wkWebConfig.preferences.javaScriptEnabled = YES;
        wkWebConfig.userContentController = wkUController;
        _webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, StatusBarHeight, ScreenW, ScreenH - StatusBarHeight - MenuBarHeight) configuration:wkWebConfig];
        _webView.navigationDelegate = self;
        _webView.allowsBackForwardNavigationGestures = YES;
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.urlString]];
        [_webView loadRequest:request];
        
        [_webView addSubview:self.progressView];
        [_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    }
    return _webView;
}

- (UIProgressView *)progressView {
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressView.frame = CGRectMake(0, StatusBarHeight, ScreenW, 0);
        _progressView.transform = CGAffineTransformMakeScale(1.0, 0.5);
        _progressView.trackTintColor = [UIColor clearColor];
        _progressView.progressTintColor = [UIColor.blueColor colorWithAlphaComponent:0.75];
    }
    return _progressView;
}

#pragma mark - 进度条
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    [self updateProgress:_webView.estimatedProgress];
}

#pragma mark - 更新进度条
- (void)updateProgress:(double)progress {
    self.progressView.alpha = 1;
    if (progress > _lastProgress) {
        [self.progressView setProgress:self.webView.estimatedProgress animated:YES];
    } else {
        [self.progressView setProgress:self.webView.estimatedProgress];
    }
    _lastProgress = progress;
    
    if (progress >= 1) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.progressView.alpha = 0;
            [self.progressView setProgress:0];
            self.lastProgress = 0;
        });
    }
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"开始加载:%@", _urlString);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.title = webView.title;
    [self updateProgress:webView.estimatedProgress];
    
    // 禁用缩放
    NSString *injectionJSString = @"var script = document.createElement('meta');"
    "script.name = 'viewport';"
    "script.content=\"width=device-width, user-scalable=no\";"
    "document.getElementsByTagName('head')[0].appendChild(script);";
    [webView evaluateJavaScript:injectionJSString completionHandler:nil];
    
    NSLog(@"加载完成");
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"加载失败");
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSURLRequest *request        = navigationAction.request;
    NSString     *scheme         = [request.URL scheme];

    NSString *absoluteString = [navigationAction.request.URL.absoluteString stringByRemovingPercentEncoding];
    NSLog(@"Current URL is %@",absoluteString);
    // 拦截schemes跳转 回到支付页面
    if ([absoluteString isEqualToString:[NSString stringWithFormat:@"%@://",CompanyFirstDomainByWeChatRegister]]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        if ([self.webView canGoBack])
            [self.webView goBack];
        return;
    }
    
    static NSString *endPayRedirectURL = nil;
    
    // 解决微信支付后为返回当前应用
    if ([absoluteString hasPrefix:@"https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb"] && ![absoluteString hasSuffix:[NSString stringWithFormat:@"redirect_url=%@://",CompanyFirstDomainByWeChatRegister]]) {
        decisionHandler(WKNavigationActionPolicyCancel);

        NSString *redirectUrl = nil;
        if ([absoluteString containsString:@"redirect_url="]) {
            NSRange redirectRange = [absoluteString rangeOfString:@"redirect_url"];
            endPayRedirectURL =  [absoluteString substringFromIndex:redirectRange.location+redirectRange.length+1];
            redirectUrl = [[absoluteString substringToIndex:redirectRange.location] stringByAppendingString:[NSString stringWithFormat:@"redirect_url=%@://",CompanyFirstDomainByWeChatRegister]];
        } else {
            redirectUrl = [absoluteString stringByAppendingString:[NSString stringWithFormat:@"&redirect_url=%@://",CompanyFirstDomainByWeChatRegister]];
        }
        
        NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:redirectUrl] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:XDX_URL_TIMEOUT];
        newRequest.allHTTPHeaderFields = request.allHTTPHeaderFields;
        [newRequest setValue:[NSString stringWithFormat:@"%@",CompanyFirstDomainByWeChatRegister] forHTTPHeaderField:@"Referer"];
        newRequest.URL = [NSURL URLWithString:redirectUrl];
        [webView loadRequest:newRequest];
        return;
    }
    
    if (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        if ([scheme isEqualToString:@"weixin"]) {
            if (endPayRedirectURL) {
                [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:endPayRedirectURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:XDX_URL_TIMEOUT]];
            }
        } else if ([scheme isEqualToString:[NSString stringWithFormat:@"%@",CompanyFirstDomainByWeChatRegister]]) {

        }

        // 原生拉起微信支付
        NSLog(@"handler Url:%@", request.URL.absoluteString);
        BOOL canOpen = [[UIApplication sharedApplication] canOpenURL:navigationAction.request.URL];
        if (canOpen) {
            if ([navigationAction.request.URL.absoluteString hasPrefix:@"weixin://"]) {
                [[UIApplication sharedApplication] openURL:navigationAction.request.URL options:@{} completionHandler:nil];
            }
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"你尚未安装微信APP" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil];
            [alert addAction:cancelAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
        return;
    }
  
    decisionHandler(WKNavigationActionPolicyAllow);
}

@end

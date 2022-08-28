# payDemo

### 1、查看微信支付平台的回调地址
* 也可以自定义url schemes添加到微信回调地址（最多可添加5个）

![WechatIMG64.jpeg](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/56481725338a4b338da3bd97780371fa~tplv-k3u1fbpfcp-watermark.image?)

### 2、Xcode添加配置

![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/132b96a0205a41b09b2e03a1ec4e0ac1~tplv-k3u1fbpfcp-watermark.image?)


![image.png](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/7fbd8c5849b74c68a05d8b8b848ef122~tplv-k3u1fbpfcp-watermark.image?)

### 3、WKWebView的代理方法
```Object-C
#define XDX_URL_TIMEOUT 30
static const NSString *CompanyFirstDomainByWeChatRegister = @"restaurant.pengyuns.comm";

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
```
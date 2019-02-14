//
//  YPWKWebController.m
//  OpenGLDemo01
//
//  Created by Jtg_yao on 2019/2/14.
//  Copyright © 2019年 rocHome. All rights reserved.
//

#import "YPWKWebController.h"
#import <Masonry.h>
#import "NSHTTPCookie+Utils.h"

#define kHexColor(hex) [UIColor colorWithRed:((float)((hex & 0xFF0000) >> 16)) / 255.0 green:((float)((hex & 0xFF00) >> 8)) / 255.0 blue:((float)(hex & 0xFF)) / 255.0 alpha:1]
// 检查字符串是否为空(PS：这里认为nil," ", "\n"均是空)
#define kStrIsEmpty(str)     (str==nil || [str length]==0 || [[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0)

static NSString *const kWebScriptMessageName = @"xxx";
#define kStateBarHeight      @([[UIApplication sharedApplication] statusBarFrame].size.height)

@interface YPWKWebController ()

/** webview 配置 */
@property (nonatomic,strong) WKWebViewConfiguration *webConfig;
/** 进度条 */
@property (nonatomic,strong) UIProgressView *progressView;

@property (nonatomic,copy) NSNumber *progressTop;
@property (nonatomic,copy) NSNumber *progressOffsety;

@end

@implementation YPWKWebController

-(instancetype)initWithUrl:(NSString *)webUrl hiddenTopBar:(BOOL)isHidden {
    if (self = [super init]) {
        _webUrl = webUrl;
        _progressTop = @0.0f;
        
        if (isHidden) {
            _progressOffsety = @(-kStateBarHeight.floatValue);
        } else {
            _progressOffsety = @0.0f;
        }
    }
    return self;
}

-(instancetype)init {
    if (self = [super init]) {
        _progressTop = @0.0f;
        _progressOffsety = @0.0f;
    }
    return self;
}

-(void)dealloc {
    
    [self.webView removeObserver:self forKeyPath:@"title"];
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    [self WKWSubViewInit];
    [self WKWAddConstraints];
    [self WKWDataInit];
}

-(void)WKWSubViewInit {
    
    self.view.backgroundColor = kHexColor(0xF0F0F0);
    
    [self.view addSubview:self.progressView];
    [self.view addSubview:self.webView];
    
    [self.webView addObserver:self forKeyPath:@"title" options:(NSKeyValueObservingOptionNew) context:nil];
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:(NSKeyValueObservingOptionNew) context:nil];
}

-(void)WKWAddConstraints {
    
    [_progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.mas_equalTo(self.view);
        make.height.mas_equalTo(@1.0f);
        make.top.mas_equalTo(self.view);
    }];
    
    [_webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.bottom.right.mas_equalTo(self.view);
        make.top.mas_equalTo(self.progressView.mas_bottom);
    }];
}

- (void)WKWDataInit{
    
    NSString *baseAgent = nil;
    if (@available(iOS 12.0, *)){
        //由于iOS12的UA改为异步，所以不管在js还是客户端第一次加载都获取不到，所以此时需要先设置好再去获取（1、如下设置；2、先在AppDelegate中设置到本地）
        NSString *baseAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 12_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15F79";
        NSString *userAgent = [NSString stringWithFormat:@"%@%@",baseAgent,@""];
        [self.webView setCustomUserAgent:userAgent];
    }
    
    __weak typeof(self) weakSelf = self;
    [_webView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id result, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSString *userAgent = result;
        
        NSString *newUserAgent = nil;
        if (baseAgent == nil) {
            newUserAgent = [userAgent stringByAppendingString:@";appName"];
        } else {
            newUserAgent = userAgent;
        }
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:newUserAgent, @"UserAgent", nil];
        
        if (@available(iOS 9.0, *)) {
            [strongSelf.webView setCustomUserAgent:newUserAgent];
        } else {
            [strongSelf.webView setValue:newUserAgent forKey:@"applicationNameForUserAgent"];
        }
        [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
        
        [strongSelf loadWebReuqest];
    }];
}

-(void)loadWebReuqest {
    
    if ([_webUrl rangeOfString:@"?"].location != NSNotFound) {
        _webUrl = [_webUrl stringByAppendingString:@"&onapp=1"];
    } else {
        _webUrl = [_webUrl stringByAppendingString:@"?onapp=1"];
    }
    
    NSURL *url = [NSURL URLWithString:_webUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:[self readCurrentCookieWithDomain:_webUrl] forHTTPHeaderField:@"Cookie"];
    [request addValue:@"iPhone" forHTTPHeaderField:@"device"];
    [self.webView loadRequest:request];
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"title"]) {
        
        NSString *webTitle = [change objectForKey:NSKeyValueChangeNewKey];
        webTitle = kStrIsEmpty(webTitle) ? (kStrIsEmpty(self.title) ? @"" : self.title) : webTitle;
        self.title = webTitle;
    } else if ([keyPath isEqualToString:@"estimatedProgress"]) {
        
        double progress = [[change objectForKey:NSKeyValueChangeNewKey] doubleValue];
        NSLog(@"estimatedProgress == %lf",progress);
        self.progressView.progress = progress;
        [self.view setNeedsUpdateConstraints];
        [self.view updateConstraintsIfNeeded];
        
        __weak typeof(self) weakSelf = self;
        self.progressTop = (progress >= 1.0f ? @(-1.0f) : @(0.0f));
        weakSelf.progressView.hidden = progress >= 1.0f;
        [self.view setNeedsUpdateConstraints];
        [self.view updateConstraintsIfNeeded];
    }
}

//更新进度条位置
-(void)updateViewConstraints{
    
    __weak typeof(self) weakSelf = self;
    [self.progressView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(weakSelf.view).with.offset(weakSelf.progressTop.floatValue + weakSelf.progressOffsety.floatValue);
    }];
    
    if (self.progressTop.floatValue == -1.0f) {
        [UIView animateWithDuration:0.8 animations:^{
            self.progressView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            self.progressView.transform = CGAffineTransformMakeScale(1.0f, 1.5f);
        }];
    }
    
    [super updateViewConstraints];
}

#pragma mark -- Delegate
#pragma mark --

#pragma mark - WKUIDelegate
- (void)webViewDidClose:(WKWebView *)webView {
    NSLog(@"webViewDidClose %s", __FUNCTION__);
}

#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    
    NSLog(@"didReceiveScriptMessage == %@", message);
    if ([message.name isEqualToString:kWebScriptMessageName]) { // 监听 注册 的方法
        
    }
}

// 在JS端调用alert函数时，会触发此代理方法。
// JS端调用alert时所传的数据可以通过message拿到
// 在原生得到结果后，需要回调JS，是通过completionHandler回调
-(void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:(UIAlertControllerStyleAlert)];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// JS端调用confirm函数时，会触发此方法
// 通过message可以拿到JS端所传的数据
// 在iOS端显示原生alert得到YES/NO后
// 通过completionHandler回调给JS端
-(void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:(UIAlertControllerStyleAlert)];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// JS端调用prompt函数时，会触发此方法
// 要求输入一段文本
// 在原生输入得到文本内容后，通过completionHandler回调给JS
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * __nullable result))completionHandler {
    NSLog(@"%s", __FUNCTION__);
    
    NSLog(@"%@", prompt);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"textinput" message:@"JS调用输入框" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.textColor = [UIColor redColor];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler([[alert.textFields lastObject] text]);
    }]];
    
    [self presentViewController:alert animated:YES completion:NULL];
}

#pragma mark - WKNavigationDelegate
// 请求开始前，会先调用此代理方法
// 与UIWebView的
// - (BOOL)webView:(UIWebView *)webView
// shouldStartLoadWithRequest:(NSURLRequest *)request
// navigationType:(UIWebViewNavigationType)navigationType;
// 类型，在请求先判断能不能跳转（请求）
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSLog(@"%s", __FUNCTION__);
    
    NSString *urlString = [webView.URL absoluteString];
    NSString *lowerUrlString = [urlString lowercaseString];

    if ([urlString containsString:@"//itunes.apple.com/"] ||
        [lowerUrlString hasPrefix:@"sms:"] ||
        [lowerUrlString hasPrefix:@"tel:"]) { // appStore 短信和打电话
        if ([[UIApplication sharedApplication] canOpenURL:webView.URL]) {
            [[UIApplication sharedApplication] openURL:webView.URL];
        } else {
            [[UIApplication sharedApplication] openURL:webView.URL options:[NSDictionary dictionary] completionHandler:nil];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

// 开始导航跳转时会回调
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    
    NSLog(@"%s", __FUNCTION__);
    NSString *urlString = [webView.URL absoluteString];
    NSLog(@"will urlString == %@",urlString);
}

// 在响应完成时，会回调此方法
// 如果设置为不允许响应，web内容就不会传过来
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;
    // 获取cookie,并设置到本地
    NSArray *cookies =[NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:response.URL];
    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

// 接收到重定向时会回调
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);
}

// 导航失败时会回调
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"%s", __FUNCTION__);
    
}

// 页面内容到达main frame时回调
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);
}

// 导航完成时，会回调（也就是页面载入完成了）
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);
    
    [self updateWebViewCookie];
}

// 导航失败时会回调
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    return;
}

//内存过大时，会出现白屏
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    [webView reload];    //刷新就好了
}

#pragma mark -- click
-(BOOL)navigationShouldPopOnBackButton {
    
    if ([self.webView canGoBack]) {
        [self.webView goBack];
        return NO;
    }
    return YES;
}

/*!
 *  更新webView的cookie
 */
- (void)updateWebViewCookie{
    WKUserScript * cookieScript = [[WKUserScript alloc] initWithSource:[self cookieString] injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    //添加Cookie
    [self.webView.configuration.userContentController addUserScript:cookieScript];
}

#pragma mark - 读取cookie值
- (NSString *)readCurrentCookieWithDomain:(NSString *)domainStr{
    NSHTTPCookieStorage*cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSMutableString * cookieString = [[NSMutableString alloc]init];
    for (NSHTTPCookie*cookie in [cookieJar cookies]) {
        [cookieString appendFormat:@"%@=%@;",cookie.name,cookie.value];
    }
    
    //删除最后一个“；”
    if(cookieString.length != 0){
        [cookieString deleteCharactersInRange:NSMakeRange(cookieString.length - 1, 1)];
    }
    return cookieString;
}

- (NSString *)cookieString{
    NSMutableString *script = [NSMutableString string];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        // Skip cookies that will break our script
        if ([cookie.value rangeOfString:@"'"].location != NSNotFound) {
            continue;
        }
        // Create a line that appends this cookie to the web view's document's cookies
        [script appendFormat:@"document.cookie='%@'; \n", cookie.da_javascriptString];
    }
    return script;
}

#pragma mark -- Getter
-(WKWebView *)webView {
    
    if (_webView == nil) {
        
        _webView = [[WKWebView alloc] initWithFrame:CGRectZero
                                      configuration:self.webConfig];
        
        _webView.navigationDelegate     = self;
        _webView.scrollView.delegate    = self;
        _webView.UIDelegate             = self;
    }
    return _webView;
}

-(WKWebViewConfiguration *)webConfig {
    
    if (_webConfig == nil) {
        
        _webConfig = [[WKWebViewConfiguration alloc] init];
        
        // 设置偏好设置
        _webConfig.preferences = [[WKPreferences alloc] init];
        // 允许 JavaScript 交互
        _webConfig.preferences.javaScriptEnabled = YES;
        // 在 iOS 默认为n NO，表示不能自动通过k窗口打开
        _webConfig.preferences.javaScriptCanOpenWindowsAutomatically = NO;
        
        // web 内容处理池， 由于没有属性可以设置，也没有属性可以设置，不用手动创建
        _webConfig.processPool = [[WKProcessPool alloc] init];
        
        // 通过 JavaScript 与 webview 内容交互
        _webConfig.userContentController = [[WKUserContentController alloc] init];
        
        // 注入 JavaScript 对象名称 kWebScriptMessageName，当JS通过 kWebScriptMessageName 来调用时，
        // 我们可以在 WKScriptMessageHandler 代理中接收到
        [_webConfig.userContentController addScriptMessageHandler:self name:kWebScriptMessageName];
    }
    return _webConfig;
}

-(UIProgressView *)progressView {
    
    if (_progressView == nil) {
        
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:(UIProgressViewStyleBar)];
        _progressView.tintColor = kHexColor(0x556281);
        _progressView.trackTintColor = kHexColor(0xF1F1F1);
    }
    return _progressView;
}

@end

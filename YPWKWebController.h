//
//  YPWKWebController.h
//  OpenGLDemo01
//
//  Created by Jtg_yao on 2019/2/14.
//  Copyright © 2019年 rocHome. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "UIViewController+BackButtonHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface YPWKWebController : UIViewController
<WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate>

@property (nonatomic,strong) WKWebView *webView;
@property (nonatomic,strong) NSString  *webUrl;

-(instancetype)initWithUrl:(NSString *)webUrl hiddenTopBar:(BOOL)isHidden ;

@end

NS_ASSUME_NONNULL_END

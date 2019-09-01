//
//  UpdateWindow.m
//  Mouse Fix
//
//  Created by Noah Nübling on 30.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "UpdateWindow.h"
#import "Updater.h"
#import "../MoreSheet/MoreSheet.h"
#import <WebKit/WebKit.h>

@interface UpdateWindow ()

@end

@implementation UpdateWindow

- (IBAction)skip:(id)sender {
    [Updater skipAvailableVersion];
    [self close];
}
- (IBAction)update:(id)sender {
    [Updater update];
    [self close];
}

- (void)windowWillClose:(NSNotification *)notification {
    
}



- (void)themeChanged:(NSNotification *)ntf {
    NSLog(@"Theme Changed!");
    [self.window performClose:NULL];
}

- (void)startWithUpdateNotes:(NSURL *)updateNotesLocation {
    [super windowDidLoad];
    
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(themeChanged:) name:@"AppleInterfaceThemeChangedNotification" object: nil];
    
    [super windowDidLoad];
    [self createWebviewWithURL:updateNotesLocation];
    
    
    CGSize win = CGSizeMake(330, 205); //(330,[JSreturn floatValue])
    CGSize dsp = NSScreen.mainScreen.frame.size;
    NSRect newWinPos = NSMakeRect((dsp.width/2.0) - (win.width/2.0), (dsp.height/2.0) - (win.height/2.0) + 50, win.width, win.height);
    [self.window setFrame:newWinPos display:YES animate:NO];
}

- (void)createWebviewWithURL:(NSURL *)updateNotesURL {
    
    [self.window setFrame:NSMakeRect(0, 0, 440, 462) display:NO animate:NO];
    NSRect WKFrm = NSMakeRect(80, 57, 340, 363); // (20, 57, 400, 332/363)
    
    
    WKWebViewConfiguration *WKConf = [[WKWebViewConfiguration alloc] init];
    [WKConf.userContentController addScriptMessageHandler:(id<WKScriptMessageHandler>)self name:@"DABIGBUM"];
    
    WKWebView *wv = [[WKWebView alloc] initWithFrame:WKFrm configuration:WKConf];
    [wv setNavigationDelegate:self];
//    [wv setUIDelegate:self];
    

    [wv loadFileURL:[updateNotesURL URLByAppendingPathComponent:@"index.html" isDirectory:NO] allowingReadAccessToURL:updateNotesURL];
    
    wv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.window.contentView addSubview:wv];

    wv.layer.cornerRadius = 5;
    wv.layer.masksToBounds = YES;

    [wv setValue:@(NO) forKey:@"drawsBackground"];
    [wv display];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"FINISCHEDD NAVIGATION");
    
    // change style according to system appearance
    if (@available(macOS 10.14, *)) {
        NSString *cssFileDir = @"Aqua";
        if (NSApplication.sharedApplication.effectiveAppearance == [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]) {
            cssFileDir = @"DarkAqua";
        }
        NSString *jsDir = [NSString stringWithFormat:@"document.getElementById('styleSheetId').href='%@.css'", cssFileDir];
        [webView evaluateJavaScript:jsDir completionHandler:^(id response, NSError *error) {
            NSLog(@"%@",error);
            NSLog(@"%@",(NSString *)response);
        }];
        
        [webView evaluateJavaScript:@"document.getElementsByTagName('h1')[0].textContent" completionHandler:^(id response, NSError *error) {
            NSLog(@"%@",error);
            NSLog(@"%@",(NSString *)response);
        }];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSLog(@"%@", navigationAction);
    if (navigationAction.navigationType == -1) {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
    else {
        decisionHandler(WKNavigationActionPolicyCancel);
        [[NSWorkspace sharedWorkspace] openURL:navigationAction.request.URL];
    }
}

@end
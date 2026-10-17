//
//  Safari.m
//  OpenHere
//
//  Created by Marc Schwieterman on 8/6/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

#import "Safari.h"
#import "SafariSupport.h"

@interface Safari ()

@property (nonatomic, readonly) NSString* bundleIdentifier;

@end

@implementation Safari

- (instancetype)initWithBundleIdentifier:(NSString*) bundleIdentifier {
    if (self = [self init]) {
        _bundleIdentifier = bundleIdentifier;
    }
    return self;
}

- (void)openURL:(NSString*) url inBrowserTarget:(BrowserTarget) browserTarget {
    NSParameterAssert(url);
    NSParameterAssert(browserTarget);
    [self openURL:url inBrowserTarget:browserTarget andActivate:false];
}

- (void)openURL:(NSString*) url inBrowserTarget:(BrowserTarget) browserTarget andActivate:(BOOL) activate {
    NSParameterAssert(url);
    NSParameterAssert(browserTarget);
    SafariApplication* application =
    [SBApplication applicationWithBundleIdentifier:self.bundleIdentifier];

    switch (browserTarget) {
        case BrowserTargetNewWindow: {
            SafariDocument* newDocument = [[[application classForScriptingClass:@"document"] alloc] init];
            [[application documents] addObject:newDocument];
            SafariWindow* frontWindow = [[application windows] firstObject];
            frontWindow.currentTab.URL = url;
            break;
        }
        case BrowserTargetNewTab: {
            SafariWindow* frontWindow = [[application windows] firstObject];
            SafariTab* newTab = [[[application classForScriptingClass:@"tab"] alloc] init];
            [[frontWindow tabs] addObject:newTab];
            // don't touch `newTab` after adding it to `tabs` - it was causing a crash
            frontWindow.currentTab = frontWindow.tabs.lastObject;
            frontWindow.currentTab.URL = url;
            break;
        }
        default: {
            // the browser is not running: Launch Services launches it and opens the URL
            [self openURLWithLaunchServices:url];
            return;
        }
    }

    if (activate) {
        [application activate];
    }
}

- (void)openURLWithLaunchServices:(NSString*) url {
    NSURL* nsurl = [NSURL URLWithString:url];
    if (!nsurl || ![[NSWorkspace sharedWorkspace] openURLs:@[nsurl] withAppBundleIdentifier:self.bundleIdentifier options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:nil]) {
        NSLog(@"Failed to open URL in %@", self.bundleIdentifier);
    }
}

@end

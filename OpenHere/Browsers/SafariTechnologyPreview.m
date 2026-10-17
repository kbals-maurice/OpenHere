//
//  SafariTechnologyPreview.m
//  OpenHere
//
//  Created by Marc Schwieterman on 11/25/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

#import "SafariTechnologyPreview.h"
#import "SafariTechnologyPreviewSupport.h"

@interface SafariTechnologyPreview ()

@property (nonatomic, readonly) NSString* bundleIdentifier;

@end

@implementation SafariTechnologyPreview

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
    SafariTechnologyPreviewApplication* application =
    [SBApplication applicationWithBundleIdentifier:self.bundleIdentifier];

    switch (browserTarget) {
        case BrowserTargetNewWindow: {
            SafariTechnologyPreviewDocument* newDocument = [[[application classForScriptingClass:@"document"] alloc] init];
            [[application documents] addObject:newDocument];
            SafariTechnologyPreviewWindow* frontWindow = [[application windows] firstObject];
            frontWindow.currentTab.URL = url;
            break;
        }
        case BrowserTargetNewTab: {
            SafariTechnologyPreviewWindow* frontWindow = [[application windows] firstObject];
            SafariTechnologyPreviewTab* newTab = [[[application classForScriptingClass:@"tab"] alloc] init];
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

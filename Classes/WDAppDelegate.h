//
//  WDAppDelegate.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import <DropboxSDK/DropboxSDK.h>

@interface WDAppDelegate : NSObject <UIApplicationDelegate, DBSessionDelegate, UIAlertViewDelegate>

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, copy) void (^performAfterDropboxLoginBlock)(void);

- (void) unlinkDropbox;

@end

extern NSString *WDDropboxWasUnlinkedNotification;


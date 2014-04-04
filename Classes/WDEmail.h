//
//  WDEmail.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>
#import <MessageUI/MFMailComposeViewController.h>

@interface WDEmail : NSObject

@property (nonatomic, assign) NSUInteger expectedAttachments;
@property (nonatomic, assign) NSUInteger completeAttachments;
@property (nonatomic, strong) MFMailComposeViewController *picker;

@end

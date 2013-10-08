//
//  WDActivityManager.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@class WDActivity;

@interface WDActivityManager : NSObject <UITableViewDataSource>

@property (nonatomic, strong) NSMutableArray *activities;
@property (nonatomic, readonly) NSUInteger count;

// add
- (void) addActivity:(WDActivity *)activity;

// find
- (WDActivity *) activityWithFilepath:(NSString *)filepath;
- (NSUInteger) indexOfActivity:(WDActivity *)activity;

// delete
- (void) removeActivityWithFilepath:(NSString *)filepath;
- (void) removeActivity:(WDActivity *)activity;

// update
- (void) updateProgressForFilepath:(NSString *)filepath progress:(float)progress;

@end

extern NSString *WDActivityAddedNotification;
extern NSString *WDActivityRemovedNotification;
extern NSString *WDActivityProgressChangedNotification;


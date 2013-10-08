//
//  WDActivityManager.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDActivity.h"
#import "WDActivityManager.h"
#import "WDProgressView.h"
#import "UIView+Additions.h"

NSString *WDActivityAddedNotification = @"WDActivityAddedNotification";
NSString *WDActivityRemovedNotification = @"WDActivityRemovedNotification";
NSString *WDActivityProgressChangedNotification = @"WDActivityProgressChangedNotification";

#define kLabelTag        1
#define kProgressTag     2

@implementation WDActivityManager

@synthesize activities;

- (id)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.activities = [NSMutableArray array];
    
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@: %@", [super description], activities];
}

- (void) addActivity:(WDActivity *)activity
{
    [activities addObject:activity];
    NSDictionary *userInfo = @{@"activity": activity,
                               @"index": @([self indexOfActivity:activity])};
    [[NSNotificationCenter defaultCenter] postNotificationName:WDActivityAddedNotification object:self userInfo:userInfo];
}

- (WDActivity *) activityWithFilepath:(NSString *)filepath
{
    for (WDActivity *activity in activities) {
        if ([activity.filePath isEqualToString:filepath]) {
            return activity;
        }
    }
    
    return nil;
}

- (NSUInteger) count
{
    return activities.count;
}

- (NSUInteger) indexOfActivity:(WDActivity *)activity
{
    return [activities indexOfObject:activity];
}

- (void) removeActivity:(WDActivity *)activity
{
    NSUInteger  index = [self indexOfActivity:activity];
    NSDictionary *userInfo = @{@"activity": activity,
                              @"index": @(index)};
    
    // do this after creating the dictionary, to make sure activity doesn't get released prematurely
    [activities removeObject:activity];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WDActivityRemovedNotification object:self userInfo:userInfo];
}

- (void) removeActivityWithFilepath:(NSString *)filepath
{
    [self removeActivity:[self activityWithFilepath:filepath]];
}

- (void) updateProgressForFilepath:(NSString *)filepath progress:(float)progress
{
    WDActivity *activity = [self activityWithFilepath:filepath];
    
    activity.progress = progress;
    
    NSDictionary *userInfo = @{@"activity": activity, 
                              @"index": @([self indexOfActivity:activity])};
    [[NSNotificationCenter defaultCenter] postNotificationName:WDActivityProgressChangedNotification object:self userInfo:userInfo];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return activities.count;
}

- (UITableViewCell *) freshCellWithIdentifier:(NSString *)identifier
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    
    CGRect frame = cell.contentView.bounds;
    frame.origin.x += 42;
    frame.size.width = (CGRectGetWidth(cell.contentView.bounds) - 10) - frame.origin.x;
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.font = [UIFont boldSystemFontOfSize:16];
    label.tag = 1;
    [cell.contentView addSubview:label];
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    WDActivity *activity = (WDActivity *) activities[indexPath.row];
    UITableViewCell *cell;
    
    if (activity.type == WDActivityTypeImport) {
        NSString    *cellIdentifier = @"indeterminateIdentifier";
        
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        
        if (cell == nil) {
            cell = [self freshCellWithIdentifier:cellIdentifier];
            
            UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            [cell.contentView addSubview:activity];
            activity.sharpCenter = CGPointMake(21, CGRectGetMidY(cell.contentView.bounds));
            [activity startAnimating];
        }
    } else {
        NSString    *cellIdentifier = @"progressIdentifier";
        
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        
        if (cell == nil) {
            cell = [self freshCellWithIdentifier:cellIdentifier];
            
            WDProgressView *progressView = [[WDProgressView alloc] initWithFrame:CGRectMake(0,0,28,28)];
            [cell.contentView addSubview:progressView];
            progressView.sharpCenter = CGPointMake(21, CGRectGetMidY(cell.contentView.bounds));
            progressView.tag = kProgressTag;
        }
    }
    
    WDProgressView *progressView = (WDProgressView *) [cell viewWithTag:kProgressTag];
    progressView.progress = activity.progress;
    
    UILabel *label = (UILabel *) [cell viewWithTag:kLabelTag];
    label.text = activity.title;
    
    return cell;
}

@end

//
//  WDActionSheet.m
//  Brushes
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2012-2013 Steve Sprang
//

#import "WDActionSheet.h"

@interface WDTagProvider : NSObject
@property (nonatomic, assign) int tag;
+ (WDTagProvider *) tagProviderWithNumber:(NSNumber *)number;
@end

@implementation WDTagProvider
@synthesize tag;

+ (WDTagProvider *) tagProviderWithNumber:(NSNumber *)number
{
    WDTagProvider *tagProvider = [[WDTagProvider alloc] init];
    tagProvider.tag = number.intValue;
    return tagProvider;
}

@end

@implementation WDActionSheet

@synthesize sheet;
@synthesize actions;
@synthesize delegate;
@synthesize tags;

+ (WDActionSheet *) sheet
{
    WDActionSheet *sheet = [[WDActionSheet alloc] init];
    return sheet;
}

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    sheet = [[UIActionSheet alloc] init];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    actions = [[NSMutableArray alloc] init];
    tags = [[NSMutableArray alloc] init];
    
    self.sheet.delegate = self;
    
    return self;
}

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex) {
        void (^action)(id) = (self.actions)[buttonIndex];
        
        WDTagProvider *sender = [WDTagProvider tagProviderWithNumber:(self.tags)[buttonIndex]];
        action(sender);
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [delegate actionSheetDismissed:self];
}

- (void) addButtonWithTitle:(NSString *)title action:(void (^)(id))action
{
    [sheet addButtonWithTitle:title];
    [self.actions addObject:[action copy]];
    [self.tags addObject:@0];
}

- (void) addButtonWithTitle:(NSString *)title action:(void (^)(id))action tag:(int)tag
{
    [sheet addButtonWithTitle:title];
    [self.actions addObject:[action copy]];
    [self.tags addObject:@(tag)];
}

- (void) addCancelButton
{
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
}

@end

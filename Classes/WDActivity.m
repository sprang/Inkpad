//
//  WDActivity.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDActivity.h"

@implementation WDActivity

@synthesize filePath;
@synthesize progress;
@synthesize type;

+ (WDActivity *) activityWithFilePath:(NSString *)filePath type:(WDActivityType)type
{
    WDActivity *activity = [[WDActivity alloc] initWithFilePath:filePath type:type];
    return activity;
}

- (id) initWithFilePath:(NSString *)aFilePath type:(WDActivityType)aType
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    self.filePath = aFilePath;
    type = aType;
    
    return self;
}

- (NSString *) description
{
    NSArray *types = @[@"DOWNLOAD", @"UPLOAD", @"IMPORT"];
    return [NSString stringWithFormat:@"%@: %@; %@; %.0f%%", [super description], types[type], self.filePath, self.progress * 100];
}

- (NSString *) title
{
    NSArray *formats = @[NSLocalizedString(@"Downloading “%@”", @"Downloading “%@”"),
                        NSLocalizedString(@"Uploading “%@”", @"Uploading “%@”"),
                        NSLocalizedString(@"Importing “%@”", @"Importing “%@”")];
    
    return [NSString stringWithFormat:formats[type], [self.filePath lastPathComponent]];
}

@end

//
//  WDMenuItem.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDMenuItem.h"

@implementation WDMenuItem

@synthesize target = target_;
@synthesize action = action_;
@synthesize title = title_;
@synthesize enabled = enabled_;
@synthesize separator = separator_;
@synthesize image = image_;
@synthesize tag = tag_;
@synthesize label = label_;
@synthesize imageView = imageView_;

+ (WDMenuItem *)separatorItem
{
    WDMenuItem *item = [[WDMenuItem alloc] init];
    
    item.separator = YES;
    
    return item;
}

+ (id)itemWithTitle:(NSString *)aString action:(SEL)aSelector target:(id)target
{
    WDMenuItem *item = [[WDMenuItem alloc] initWithTitle:aString image:nil action:aSelector target:target];
    return item;
}

+ (id)itemWithTitle:(NSString *)aString image:(UIImage *)image action:(SEL)aSelector target:(id)target
{
    WDMenuItem *item = [[WDMenuItem alloc] initWithTitle:aString image:image action:aSelector target:target];
    return item;
}

- (id)initWithTitle:(NSString *)aString image:(UIImage *)image action:(SEL)aSelector target:(id)target
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    title_ = aString;
    action_ = aSelector;
    target_ = target;
    enabled_ = YES;
    self.image = image;
    
    return self;
}

- (float) imageWidth
{
    return image_ ? image_.size.width : 0.0f;
}

- (void) setEnabled:(BOOL)enabled
{
    enabled_ = enabled;
    
    self.label.alpha = enabled ? 1.0f : 0.2f;
    self.imageView.alpha = enabled ? 1.0f : 0.2f;
}

@end

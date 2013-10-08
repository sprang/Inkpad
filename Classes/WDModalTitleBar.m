//
//  WDModalTitleBar.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDModalTitleBar.h"

@implementation WDModalTitleBar

@synthesize cornerRadius;
@synthesize roundedCorners;

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    self.backgroundColor = nil;
    
    return self;
}

- (BOOL) hadRoundedCorners
{
    return (cornerRadius > 0 && self.roundedCorners);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    
    if ([self hadRoundedCorners]) {
        CGContextSaveGState(ctx);
        
        CGSize radii = CGSizeMake(self.cornerRadius, self.cornerRadius);
        UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                         byRoundingCorners:self.roundedCorners
                                                               cornerRadii:radii];
        
        [shadowPath addClip];
    }
    
    [super drawRect:rect];
    
    if ([self hadRoundedCorners]) {
        CGContextRestoreGState(ctx);
    }
}
    
@end

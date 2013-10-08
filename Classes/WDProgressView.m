//
//  WDProgressView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDProgressView.h"
#import "WDUtilities.h"

@implementation WDProgressView

@synthesize progress;

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    self.backgroundColor = nil;
    
    return self;
}

- (void) setProgress:(float)inProgress
{
    progress = WDClamp(0, 1, inProgress);
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    CGRect          bounds = CGRectInset(self.bounds, 1, 1);
    CGPoint         center = WDCenterOfRect(bounds);
    
    [[UIColor colorWithWhite:0.8f alpha:1.0f] set];
    CGContextFillEllipseInRect(ctx, bounds);
    
    if (progress > 0) {
        [[UIColor colorWithWhite:0.5f alpha:1.0f] set];
        CGContextMoveToPoint(ctx, center.x, center.y);
        
        float startAngle = -(M_PI / 2);
        float endAngle = (M_PI * 2) * progress + startAngle;
        
        CGContextAddArc(ctx, center.x, center.y, CGRectGetWidth(bounds) / 2 - 3, startAngle, endAngle, false);
        CGContextClosePath(ctx);
        
        CGContextFillPath(ctx);
    }
}

@end

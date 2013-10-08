//
//  WDShadowWell.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDColor.h"
#import "WDShadow.h"
#import "WDShadowWell.h"
#import "WDUtilities.h"

@implementation WDShadowWell

@synthesize barButtonItem = barButtonItem_;
@synthesize shadow = shadow_;
@synthesize opacity = opacity_;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
	}
    
	return self;
}

- (void) setOpacity:(float)opacity
{
    if (opacity_ == opacity) {
        return;
    }
    
    opacity_ = opacity;
    [self setNeedsDisplay];
}

- (void) setShadow:(WDShadow *)shadow
{
    if ([shadow_ isEqual:shadow]) {
        return;
    }
    
    shadow_ = shadow;
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    CGRect          bounds = [self bounds];
    
    if (barButtonItem_) {
        int inset = ceil((CGRectGetHeight(bounds) - CGRectGetWidth(bounds)) / 2);
        bounds = CGRectInset(bounds, 0, inset);
    }
    
    WDDrawCheckersInRect(ctx, bounds, 7);
    
    CGContextSaveGState(ctx);
    CGContextSetAlpha(ctx, opacity_);
    
    if (shadow_) {
        float x = cos(shadow_.angle) * 3;
        float y = sin(shadow_.angle) * 3;
        
        CGContextSetShadowWithColor(ctx, CGSizeMake(x,y), 2, shadow_.color.CGColor);
    }
    
    [[UIColor whiteColor] set];
    CGContextSetLineWidth(ctx, 6);
    CGContextStrokeEllipseInRect(ctx, CGRectInset(bounds, 7, 7));
    
    CGContextRestoreGState(ctx);
}

@end

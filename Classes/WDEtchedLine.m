//
//  WDEtchedLine.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDEtchedLine.h"

@implementation WDEtchedLine

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // draw a 1 pixel line on all displays
    float strokeWidth = 1.0f / [UIScreen mainScreen].scale;
    float y = strokeWidth / 2.0f;
    float x = self.frame.size.width;
    
    CGContextSetLineWidth(ctx, strokeWidth);
    
    // dark edge
    [[UIColor colorWithWhite:0.5f alpha:0.5f] set];
    CGContextMoveToPoint(ctx, 0, y);
    CGContextAddLineToPoint(ctx, x, y);
    CGContextStrokePath(ctx);

    // light edge
    y += strokeWidth;
    [[UIColor colorWithWhite:1.0f alpha:0.5f] set];
    CGContextMoveToPoint(ctx, 0, y);
    CGContextAddLineToPoint(ctx, x, y);
    CGContextStrokePath(ctx);
}

@end

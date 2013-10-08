//
//  WDGradientStopIndicator.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDColor.h"
#import "WDGradientStopIndicator.h"
#import "WDGradientStop.h"
#import "WDUtilities.h"

const float kColorRectInset = 10;

@implementation WDGradientStopOverlay
@synthesize indicator;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    self.backgroundColor = nil;
    
    self.layer.shadowOpacity = 0.5f;
    self.layer.shadowRadius = 1;
    self.layer.shadowOffset = CGSizeMake(0, 0);
    
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    CGRect          colorRect = [indicator colorRect];
    
    CGRect outsideRect = CGRectInset(colorRect, -2, -2);
    outsideRect.size.height -= 1;
    outsideRect.origin.y += 1;
    
    CGMutablePathRef pathRef = CGPathCreateMutable();
    
    CGPathMoveToPoint(pathRef, NULL, CGRectGetMinX(outsideRect), CGRectGetMinY(outsideRect));
    CGPathAddLineToPoint(pathRef, NULL, CGRectGetMidX(self.bounds), CGRectGetMinY(self.bounds) + 0);
    CGPathAddLineToPoint(pathRef, NULL, CGRectGetMaxX(outsideRect), CGRectGetMinY(outsideRect));
    
    CGPathAddLineToPoint(pathRef, NULL, CGRectGetMaxX(outsideRect), CGRectGetMaxY(outsideRect));
    CGPathAddLineToPoint(pathRef, NULL, CGRectGetMinX(outsideRect), CGRectGetMaxY(outsideRect));
    CGPathCloseSubpath(pathRef);
    
    CGPathAddRect(pathRef, NULL, CGRectInset(colorRect, 1, 1));
    
    [[UIColor whiteColor] set];
    CGContextAddPath(ctx, pathRef);
    CGContextEOFillPath(ctx);
    
    if (indicator.selected) {
        CGRect selectionRect = CGRectOffset(outsideRect, 0, outsideRect.size.height);
        selectionRect.size.height = 2;
        
        [[UIColor colorWithRed:0.0f green:(118.0f / 255.0) blue:1.0f alpha:1.0f] set];
        CGContextFillRect(ctx, selectionRect);
    }
    
    CGPathRelease(pathRef);
}

@end


@implementation WDGradientStopIndicator

@synthesize stop = stop_;
@synthesize selected = selected_;
@synthesize overlay = overlay_;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    self.backgroundColor = nil;
    
    return self;
}

- (id) initWithStop:(WDGradientStop *)stop
{
    self = [self initWithFrame:CGRectMake(0,0,39,39)];
    
    if (!self) {
        return nil;
    }
    
    self.stop = stop;
    
    overlay_ = [[WDGradientStopOverlay alloc] initWithFrame:self.bounds];
    overlay_.indicator = self;
    [self addSubview:overlay_];
    
    return self;
}

- (void) setStop:(WDGradientStop *)stop
{
    stop_ = stop;
    [self setNeedsDisplay];
}

- (void) setSelected:(BOOL)flag
{
    selected_ = flag;
    [overlay_ setNeedsDisplay];
}

- (CGRect) colorRect
{
    CGRect rect = self.bounds;
    rect = CGRectInset(rect, kColorRectInset, kColorRectInset);
    rect.size.height = rect.size.width;
    rect.origin.y = CGRectGetHeight(self.bounds) - CGRectGetHeight(rect) - (kColorRectInset - 1);
    
    return rect;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    CGRect          colorRect = [self colorRect];
    
    WDDrawTransparencyDiamondInRect(ctx, colorRect);
    [stop_.color set];
    CGContextFillRect(ctx, colorRect);
}

@end

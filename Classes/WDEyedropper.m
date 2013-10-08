//
//  WDEyedropper.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#import "WDEyedropper.h"
#import "WDColor.h"
#import "WDUtilities.h"

@implementation WDEyedropper

@synthesize fill = fill_;

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    
	return self;
}

- (void) setFill:(id)fill
{
    if ([fill isEqual:fill_] || (!fill && !fill_)) {
        return;
    }
    
    fill_ = fill;
    
    [self setNeedsDisplay];
}

- (void) setBorderWidth:(float)width
{
    borderWidth_ = width;
    
    CGRect          bounds = [self bounds];
    CGRect          outerBounds = CGRectInset(bounds, 10, 10);
    CGRect          innerBounds = CGRectInset(outerBounds, borderWidth_, borderWidth_);
    CGPoint         center = WDCenterOfRect(bounds);
    
    // create a shadow path in the shape of the eyedropper
    CGMutablePathRef path = CGPathCreateMutable();
    
    // flip one of the ellipses so that we get a hole in the shadow
    CGAffineTransform tX = CGAffineTransformMakeTranslation(center.x, center.y);
    tX = CGAffineTransformScale(tX, 1, -1);
    const CGAffineTransform flip = CGAffineTransformTranslate(tX, -center.x, -center.y);
    
    CGPathAddEllipseInRect(path, &flip , outerBounds);
    CGPathAddEllipseInRect(path, NULL, innerBounds);
    
    self.layer.shadowOffset = CGSizeMake(0, 3);
    self.layer.shadowRadius = 5;
    self.layer.shadowOpacity = 0.4f;
    self.layer.shadowPath = path;
    
    CGPathRelease(path);
    
    [self setNeedsDisplay];
}

- (void) drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    CGRect          bounds = [self bounds];
    CGRect          outerBounds = CGRectInset(bounds, 10, 10);
    CGRect          outerBounds2 = CGRectInset(outerBounds, 2.5, 2.5);
    CGRect          innerBounds = CGRectInset(outerBounds, borderWidth_, borderWidth_);
    
    // primary color fill
    CGContextAddEllipseInRect(ctx, outerBounds);
    CGContextAddEllipseInRect(ctx, innerBounds);
    
    CGContextSaveGState(ctx);
    CGContextEOClip(ctx);
    fill_ ? [fill_ drawEyedropperSwatchInRect:outerBounds] : [[WDColor whiteColor] drawEyedropperSwatchInRect:outerBounds];
    CGContextRestoreGState(ctx);
    
    // outside edge
    CGContextAddEllipseInRect(ctx, outerBounds);
    CGContextAddEllipseInRect(ctx, outerBounds2);
    
    CGContextSetGrayFillColor(ctx, 0.85, 1.0);
    CGContextEOFillPath(ctx);
    
    // more outside edge
    CGContextSetLineWidth(ctx, 1.0f);
    CGContextSetGrayStrokeColor(ctx, 0.6, 1.0);
    
    CGContextStrokeEllipseInRect(ctx, outerBounds);
    CGContextStrokeEllipseInRect(ctx, outerBounds2);
    
    // inside edge
    CGContextStrokeEllipseInRect(ctx, innerBounds);
    
    // draw cross hairs in the center
    CGContextSetGrayStrokeColor(ctx, 0.4, 1.0);
    
    CGPoint center = WDAddPoints(WDRoundPoint(WDCenterOfRect(bounds)), CGPointMake(0.5, 0.5));
    CGPoint points[8];
    
    points[0] = WDSubtractPoints(center, CGPointMake(10, 0));
    points[1] = WDSubtractPoints(center, CGPointMake(2, 0));
    
    points[2] = WDAddPoints(center, CGPointMake(10, 0));
    points[3] = WDAddPoints(center, CGPointMake(2, 0));
    
    points[4] = WDSubtractPoints(center, CGPointMake(0, 10));
    points[5] = WDSubtractPoints(center, CGPointMake(0, 2));
    
    points[6] = WDAddPoints(center, CGPointMake(0, 10));
    points[7] = WDAddPoints(center, CGPointMake(0, 2));
    
    CGContextStrokeLineSegments(ctx, points, 8);
}

// touches fall through
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

@end

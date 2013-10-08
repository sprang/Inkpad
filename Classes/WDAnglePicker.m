//
//  WDAnglePicker.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDAnglePicker.h"
#import "WDUtilities.h"

const float kArrowInset = 5;
const float kArrowDimension = 6;

@implementation WDAnglePicker

@synthesize value = value_;

- (void) awakeFromNib
{
    self.exclusiveTouch = YES;
    
    self.layer.shadowOpacity = 0.15f;
    self.layer.shadowRadius = 2;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    
    CGMutablePathRef pathRef = CGPathCreateMutable();
    CGRect rect = CGRectInset(self.bounds, 1, 1);
    CGPathAddEllipseInRect(pathRef, NULL, rect);
    self.layer.shadowPath = pathRef;
    CGPathRelease(pathRef);
}

- (void) drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    float           radius = CGRectGetWidth(self.bounds) / 2 - kArrowInset;
    CGPoint         center = WDCenterOfRect(self.bounds);
    CGRect          ellipseRect = CGRectInset(self.bounds, 1, 1);
    
    [[UIColor whiteColor] set];
    CGContextFillEllipseInRect(ctx, ellipseRect);
    
    [[UIColor lightGrayColor] set];
    CGContextSetLineWidth(ctx, 1.0 / [UIScreen mainScreen].scale);
    CGContextStrokeEllipseInRect(ctx, ellipseRect);
    
    // draw an arrow to indicate direction
    CGContextSaveGState(ctx);
    
    [[UIColor colorWithRed:0.0f green:(118.0f / 255.0f) blue:1.0f alpha:1.0f] set];
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineWidth(ctx, 2.0f);
    
    CGContextTranslateCTM(ctx, center.x, center.y);
    CGContextRotateCTM(ctx, value_);
    
    CGContextMoveToPoint(ctx, 0, 0);
    CGContextAddLineToPoint(ctx, radius - 0.5f, 0);
    CGContextStrokePath(ctx);
    
    CGContextMoveToPoint(ctx, radius - kArrowDimension, kArrowDimension);
    CGContextAddLineToPoint(ctx, radius, 0);
    CGContextAddLineToPoint(ctx, radius - kArrowDimension, -kArrowDimension);
    CGContextStrokePath(ctx);
    
    CGContextRestoreGState(ctx);
}

- (void) setValue:(float)value
{
    value_ = value;
    [self setNeedsDisplay];
}

- (BOOL) beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    initialValue_ = value_;
    initialTap_ = [touch locationInView:self];
    
    return [super beginTrackingWithTouch:touch withEvent:event];
}

- (BOOL) continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint     pt = [touch locationInView:self];
    CGPoint     pivot = WDCenterOfRect(self.bounds);
    CGPoint     delta = WDSubtractPoints(initialTap_, pivot);
    
    double offsetAngle = atan2(delta.y, delta.x);
    
    delta = WDSubtractPoints(pt, pivot);
    double angle = atan2(delta.y, delta.x);
    double diff = angle - offsetAngle;
    
    self.value = fmod(initialValue_ + diff, M_PI * 2);
    
    return [super continueTrackingWithTouch:touch withEvent:event];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    [super endTrackingWithTouch:touch withEvent:event];
}

@end

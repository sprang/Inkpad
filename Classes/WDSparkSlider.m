//
//  WDSparkSlider.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDSparkSlider.h"
#import "WDUtilities.h"
#import "UIView+Additions.h"

#define kValueLabelHeight   20
#define kTitleLabelHeight   18
#define kBarInset           8
#define kBarHeight          1
#define kDragDampening      1.5

@implementation WDSparkSlider

@synthesize title = title_;
@synthesize value = value_;
@synthesize minValue = minValue_;
@synthesize maxValue = maxValue_;

- (void) awakeFromNib
{
    self.opaque = NO;
    self.backgroundColor = nil;
    
    // set up the label that indicates the current value
    CGRect frame = self.bounds;
    frame.size.height = kValueLabelHeight;
    valueLabel_ = [[UILabel alloc] initWithFrame:frame];
    
    valueLabel_.opaque = NO;
    valueLabel_.backgroundColor = nil;
    valueLabel_.text = @"0 pt";
    valueLabel_.font = [UIFont systemFontOfSize:17];
    valueLabel_.textColor = [UIColor blackColor];
    valueLabel_.textAlignment = NSTextAlignmentCenter;
    
    [self addSubview:valueLabel_];
    
    // set up the title label
    frame = self.bounds;
    frame.origin.y = CGRectGetMaxY(frame) - kTitleLabelHeight;
    frame.size.height = kTitleLabelHeight;
    
    title_ = [[UILabel alloc] initWithFrame:frame];
    
    title_.opaque = NO;
    title_.backgroundColor = nil;
    title_.font = [UIFont systemFontOfSize:13];
    title_.textColor = [UIColor darkGrayColor];
    title_.textAlignment = NSTextAlignmentCenter;
    
    [self addSubview:title_];
    
    maxValue_ = 100;
}

- (CGRect) trackRect
{
    CGRect  trackRect = self.bounds;
    
    trackRect.origin.y += kValueLabelHeight;
    trackRect.size.height -= kValueLabelHeight + kTitleLabelHeight;
    trackRect = CGRectInset(trackRect, kBarInset, 0);
    
    trackRect.origin.y = WDCenterOfRect(trackRect).y;
    trackRect.size.height = kBarHeight;
    
    return trackRect;
}

- (void) drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    CGRect          trackRect = [self trackRect];
    
    // gray track backround
    [[UIColor colorWithWhite:0.75f alpha:1.0f] set];
    CGContextFillRect(ctx, trackRect);
    
    // bottom highlight
    [[UIColor colorWithWhite:1 alpha:0.6] set];
    CGContextFillRect(ctx, CGRectOffset(trackRect, 0,1));
    
    // "progress" bar
    trackRect.size.width *= ((float) value_) / maxValue_;
    [[UIColor blackColor] set];
    CGContextFillRect(ctx, trackRect);
}

- (void) updateIndicator
{
    if (!indicator_) {
        indicator_ = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"spark_knob.png"]];
        [self addSubview:indicator_];
    }
    
    CGRect trackRect = [self trackRect];
    
    trackRect = CGRectInset(trackRect, 2.5f, 0);
    trackRect.size.width *= ((float) value_) / maxValue_;
    
    indicator_.sharpCenter = CGPointMake(CGRectGetMaxX(trackRect), CGRectGetMidY(trackRect));
}

- (NSNumber *) numberValue
{
    return @((int)value_);
}

- (void) setValue:(float)value
{
    if (value == value_) {
        if (!indicator_) {
            // make sure we start in a good state
            [self updateIndicator];
        }
        
        return;
    }

    value_ = value;
    [self setNeedsDisplay];
    
    [self updateIndicator];
    
    int rounded = round(value_);
    valueLabel_.text = [NSString stringWithFormat:@"%d pt", rounded];
}

- (BOOL) beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    initialValue_ = value_;
    
    dragging_ = YES;
    moved_ = NO;
    
    indicator_.image = [UIImage imageNamed:@"spark_knob_highlighted.png"];
    
    [self setNeedsDisplay];
    
    return [super beginTrackingWithTouch:touch withEvent:event];
}

- (BOOL) continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint     delta, pt = [touch locationInView:self];
    float       changedValue;
    
    if (!moved_) {
        moved_ = YES;
        initialPt_ = pt;
    }
    
    delta = WDSubtractPoints(pt, initialPt_);
    changedValue = round(initialValue_ + (delta.x / kDragDampening));
    
    if (changedValue < minValue_) {
        changedValue = minValue_;
    } else if (changedValue > maxValue_) {
        changedValue = maxValue_;
    }
    
    self.value = changedValue;
    
    return [super continueTrackingWithTouch:touch withEvent:event];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    dragging_ = NO;
    [self setNeedsDisplay];
    
    indicator_.image = [UIImage imageNamed:@"spark_knob.png"];
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    [super endTrackingWithTouch:touch withEvent:event];
}

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    dragging_ = NO;
    [self setNeedsDisplay];
    
    indicator_.image = [UIImage imageNamed:@"spark_knob.png"];
}

@end

//
//  WDRulerView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDRulerView.h"
#import "WDRulerUnit.h"
#import "WDCanvas.h"

#define kLabelMarkEnd   0
#define kBigMarkEnd     11
#define kMidMarkEnd     13
#define kNormalMarkEnd  15

#define kMinLabelDistance   50
#define kMinMarkDistance    5

const int kWDRulerThickness = 18;

@implementation WDRulerView

@synthesize orientation = orientation_;
@synthesize ruleThickness = ruleThickness_;
@synthesize clientView = clientView_;
@synthesize units = units_;
@synthesize labelFormat = labelFormat_;

static NSMutableDictionary *registeredUnits_ = nil;

+ (void) initialize
{
    if (self != [WDRulerView class]) {
        return;
    }
    
    NSArray *stepUp52 = @[@5.0f, @2.0f];
    
    [self registerUnitWithName:@"Points" abbreviation: @"pt" unitToPointsConversionFactor:1.0f 
                   stepUpCycle:stepUp52 stepDownCycle:@[@0.5f]];
    
    [self registerUnitWithName:@"Picas" abbreviation: @"pc" unitToPointsConversionFactor:12.0f 
                   stepUpCycle:@[@2.0f] stepDownCycle:@[@0.5f]];
    
    [self registerUnitWithName:@"Inches" abbreviation:@"in" unitToPointsConversionFactor:72.0f
                   stepUpCycle:@[@2.0f]
                 stepDownCycle:@[@0.5f]];
    
    [self registerUnitWithName:@"Millimeters" abbreviation:@"mm" unitToPointsConversionFactor:2.835f
                   stepUpCycle:stepUp52
                 stepDownCycle:@[@0.5f, @0.2f]];
    
    [self registerUnitWithName:@"Centimeters" abbreviation:@"cm" unitToPointsConversionFactor:28.35f
                   stepUpCycle:@[@2.0f]
                 stepDownCycle:@[@0.5f, @0.2f]];

    [self registerUnitWithName:@"Pixels" abbreviation: @"px" unitToPointsConversionFactor:1.0f 
               stepUpCycle:stepUp52 stepDownCycle:@[@0.5f]];

}

+ (void)registerUnitWithName:(NSString *)unitName abbreviation:(NSString *)abbreviation unitToPointsConversionFactor:(CGFloat)conversionFactor
                 stepUpCycle:(NSArray *)stepUpCycle stepDownCycle:(NSArray *)stepDownCycle
{
    if (!registeredUnits_) {
        registeredUnits_ = [[NSMutableDictionary alloc] init];
    }
    
    WDRulerUnit *rulerUnit = [WDRulerUnit rulerUnitWithName:unitName abbeviation:abbreviation unitToPointsConversionFactor:conversionFactor stepUpCycle:stepUpCycle stepDownCycle:stepDownCycle];
    registeredUnits_[unitName] = rulerUnit;
}

+ (NSDictionary *) rulerUnits
{
    return registeredUnits_;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (!self) {
        return nil;
    }
    
    self.alpha = 0.5f;
    self.units = @"Inches";
    
    return self;
}

- (void) setUnits:(NSString *)units
{
    units_ = units;
    
    [self setNeedsDisplay];
}

- (WDRulerUnit *) rulerUnit
{
    return registeredUnits_[self.units];
}

- (float) stepForIndex:(int)index
{
    NSArray *stepCycle;
    
    if (index > 0)  {
        stepCycle = self.rulerUnit.stepUpCycle;
        index = (index - 1) % [stepCycle count];
        return [stepCycle[index] floatValue];
    } else  {
        stepCycle = self.rulerUnit.stepDownCycle;
        index = (-index) % [stepCycle count];
        return (1.0f / [stepCycle[index] floatValue]);
    }
}

- (void) computeMarkValues
{
    CGAffineTransform   canvasTransform = ((WDCanvas *) clientView_).canvasTransform;
    WDRulerUnit         *unit = [self rulerUnit];
    
    // convert unit in document space into ruler space
    CGSize unitSize = CGSizeMake(unit.conversionFactor, unit.conversionFactor);
    unitSize = CGSizeApplyAffineTransform(unitSize, canvasTransform);
    
    unitDistance_ = (orientation_ == WDHorizontalRuler) ? unitSize.width : unitSize.height;
    
    markDistance_ = unitDistance_;
    int stepIndex = 0;
    
    while (markDistance_ > kMinMarkDistance) {
        markDistance_ /= [self stepForIndex:stepIndex];
        stepIndex--;
    }
    while (markDistance_ < kMinMarkDistance) {
        stepIndex++;
        markDistance_ *= [self stepForIndex:stepIndex];
    }
    
    marksToMidMark_ = rint([self stepForIndex:stepIndex + 1]);
    marksToBigMark_ = marksToMidMark_ * rint([self stepForIndex:stepIndex + 2]);
    
    float labelDistance = unitDistance_;
    while (labelDistance < kMinLabelDistance) {
        stepIndex++;
        labelDistance *= [self stepForIndex:stepIndex];
    }
    
    marksBetweenLabels_ = rint(labelDistance / markDistance_);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef        ctx = UIGraphicsGetCurrentContext();
    UIFont              *font = [UIFont systemFontOfSize:11];
    float               zeroLocation, firstVisibleLocation, lastVisibleLocation;
    
    CGContextSetLineWidth(ctx, 1);
    
    [[UIColor colorWithWhite:1.0f alpha:1.0] set];
    CGContextFillRect(ctx, rect);
    
    [self computeMarkValues];
    
    CGPoint zero = CGPointZero;
    
    CGAffineTransform   canvasTransform = ((WDCanvas *) clientView_).canvasTransform;
    zero = CGPointApplyAffineTransform(zero, canvasTransform);
    
    if (orientation_ == WDHorizontalRuler) {
        zeroLocation = zero.x - self.frame.origin.x;
        firstVisibleLocation = CGRectGetMinX(self.bounds);
        lastVisibleLocation = CGRectGetMaxX(self.bounds);
    } else {
        zeroLocation = zero.y - self.frame.origin.y;
        firstVisibleLocation = CGRectGetMinY(self.bounds);
        lastVisibleLocation = CGRectGetMaxY(self.bounds);
    }
    
    int firstMark = floor((firstVisibleLocation - zeroLocation) / markDistance_);
    int lastMark = ceil((lastVisibleLocation - zeroLocation) / markDistance_);
    
    [[UIColor blackColor] set];
    
    for (int mark = firstMark; mark < lastMark; mark++) {
        float pos = floor(zeroLocation + mark * markDistance_) + 0.5;
        
        [[UIColor darkGrayColor] set];
        
        if (orientation_ == WDHorizontalRuler) {
            CGContextMoveToPoint(ctx, pos, kWDRulerThickness);
        } else {
            CGContextMoveToPoint(ctx, kWDRulerThickness, pos);
        }
        
        float markEnd = kNormalMarkEnd;
        if (mark % marksBetweenLabels_ == 0) {
            markEnd = kLabelMarkEnd;
        } else if (mark % marksToBigMark_ == 0)  {
            markEnd = kBigMarkEnd;
        } else if (mark % marksToMidMark_ == 0){
            markEnd = kMidMarkEnd;
        }
        
        if (orientation_ == WDHorizontalRuler) {
            CGContextAddLineToPoint(ctx, pos, markEnd);
        } else {
            CGContextAddLineToPoint(ctx, markEnd, pos);
        }

        CGContextStrokePath(ctx);
    }

    int firstVisibleLabel = floor((firstVisibleLocation - zeroLocation) / (marksBetweenLabels_ * markDistance_));
    int lastVisibleLabel = floor((lastVisibleLocation - zeroLocation)  / (marksBetweenLabels_ * markDistance_));
 
    for (int label = firstVisibleLabel; label <= lastVisibleLabel; label++) {
        float labelLocation = zeroLocation + label * marksBetweenLabels_ * markDistance_;
        float labelValue = (labelLocation - zeroLocation) / unitDistance_;
        if (labelValue < 0) {
            labelValue *= -1;
            [[UIColor grayColor] set];
        } else {
            [[UIColor blackColor] set];
        }
        
        NSString *label = [NSString stringWithFormat:@"%1.f", labelValue];
        CGPoint labelLoc = (orientation_ == WDHorizontalRuler) ? CGPointMake(labelLocation + 3, 0) : CGPointMake(3, labelLocation);
        NSDictionary *attrs = @{NSFontAttributeName: font};
        if (orientation_ == WDHorizontalRuler) {
            [label drawAtPoint:labelLoc withAttributes:attrs];
        } else {
            for (int i = 0; i < label.length; i++) {
                NSString *glyph = [label substringWithRange:NSMakeRange(i,1)];
                CGSize glyphSize = [glyph sizeWithAttributes:attrs];
                glyphSize.height -= 4;
                [glyph drawAtPoint:labelLoc withAttributes:attrs];
                labelLoc.y += glyphSize.height;
            }
        }
    }
    
    // draw highlight/shadow edges
    CGRect edgeRect = CGRectInset(self.bounds, 0.5f, 0.5f);
    
    if (orientation_ == WDHorizontalRuler) {
        edgeRect.size.height++;
        
        edgeRect = CGRectInset(edgeRect, -1, 0);
        [[UIColor whiteColor] set];
        CGContextStrokeRect(ctx, edgeRect);
        
        edgeRect = CGRectOffset(edgeRect, 0, -1);
        [[UIColor blackColor] set];
        CGContextStrokeRect(ctx, edgeRect);
    } else {
        edgeRect.size.width++;
        
        edgeRect = CGRectInset(edgeRect, 0, -1);
        [[UIColor whiteColor] set];
        CGContextStrokeRect(ctx, edgeRect);
        
        edgeRect = CGRectOffset(edgeRect, -1, 0);
        [[UIColor blackColor] set];
        CGContextStrokeRect(ctx, edgeRect);
    }
}

- (void) setOrientation:(WDRulerOrientation)orientation
{
    orientation_ = orientation;
    
    if (orientation == WDHorizontalRuler) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    } else {
        self.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    }
}

@end

/**************************
 * WDRulerCornerView 
 **************************/

@implementation WDRulerCornerView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.alpha = 0.5f;
    
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    [[UIColor colorWithWhite:1.0f alpha:1.0] set];
    CGContextFillRect(ctx, rect);
    
    CGContextSetLineWidth(ctx, 1);
    
    [[UIColor blackColor] set];
    CGContextStrokeRect(ctx, CGRectInset(self.bounds, 0.5f, 0.5f));
    
    [[UIColor whiteColor] set];
    CGRect topEdge = self.bounds;
    topEdge.size.height = 1;
    CGContextFillRect(ctx, topEdge);
    
    CGRect leftEdge = self.bounds;
    leftEdge.size.width = 1;
    CGContextFillRect(ctx, leftEdge);
}

@end

//
//  WDGradient.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2000-2013 Steve Sprang
//

#import "WDColor.h"
#import "WDFillTransform.h"
#import "WDGradient.h"
#import "WDGradientStop.h"
#import "WDPath.h"
#import "WDText.h"
#import "WDUtilities.h"

NSString *WDGradientTypeKey = @"WDGradientTypeKey";
NSString *WDGradientStopsKey = @"WDGradientStopsKey";


@implementation WDGradient

@synthesize type = type_;
@synthesize stops = stops_;

+ (WDGradient *) randomGradient
{
    NSMutableArray *stops = [NSMutableArray array];
    
    for (int i = 0; i < 3; i++) {
        float ratio = random() % 10000;
        ratio /= 10000;
        [stops addObject:[WDGradientStop stopWithColor:[WDColor randomColor] andRatio:ratio]];
    }
    
    return [WDGradient gradientWithType:(int) (random() % 2) stops:stops];
}

// returns a gradient that fades from black to white
+ (WDGradient *) defaultGradient
{
    return [WDGradient gradientWithStart:[WDColor blackColor] andEnd:[WDColor whiteColor]];
}

// returns a simple gradient with a start and end color
+ (WDGradient *) gradientWithStart:(WDColor *)start andEnd:(WDColor *)end
{
    WDGradient *gradient;
    
    NSArray *stops = @[[WDGradientStop stopWithColor:start andRatio:0.0],
                             [WDGradientStop stopWithColor:end andRatio:1.0]];
    
    gradient = [[WDGradient alloc] initWithType:kWDLinearGradient stops:stops];

    return gradient;
}

+ (WDGradient *) gradientWithType:(WDGradientType)type stops:(NSArray *)stops
{
    WDGradient *g = [[WDGradient alloc] initWithType:type stops:stops];
    return g;
}

- (id) initWithType:(WDGradientType)type stops:(NSArray *)stops
{
    self = [super init];

    if (!self) {
        return nil;
    }
    
    if (!stops || !stops.count) {
        WDLog(@"-[WDGradient initWithType:stops:] called with empty stop array!");
        
        stops = @[[WDGradientStop stopWithColor:[WDColor blackColor] andRatio:0.0],
                  [WDGradientStop stopWithColor:[WDColor whiteColor] andRatio:1.0]];
    }
    
    stops_ = [stops sortedArrayUsingSelector:@selector(compare:)];
    type_ = type;
    
    return self;
}

- (void) dealloc
{
    CGGradientRelease(gradientRef_);
}

- (WDGradient *) gradientByReversing
{
    NSMutableArray *reversed = [NSMutableArray array];
    
    for (WDGradientStop *stop in [stops_ reverseObjectEnumerator]) {
        [reversed addObject:[stop stopWithRatio:(1.0f - stop.ratio)]];
    }
    
    return [self gradientWithStops:reversed];
}

- (WDGradient *) gradientByDistributingEvenly
{
    NSMutableArray  *distributed = [NSMutableArray array];
    float           spacing;
    float           offset = 0.0f;
    
    spacing = 1.0 / (stops_.count - 1);
    
    for (WDGradientStop *stop in stops_) {
        [distributed addObject:[stop stopWithRatio:offset]];
        offset += spacing;
    }
         
    return [self gradientWithStops:distributed];
}

- (WDGradient *) adjustColor:(WDColor * (^)(WDColor *color))adjustment
{
    NSMutableArray *adjusted = [NSMutableArray array];
    
    for (WDGradientStop *stop in stops_) {
        [adjusted addObject:[stop stopWithColor:[stop.color adjustColor:adjustment]]];
    }
    
    return [self gradientWithStops:adjusted];
}

- (WDGradient *) gradientWithStops:(NSArray *)stops
{
    return [WDGradient gradientWithType:self.type stops:stops];
}

- (WDGradient *) gradientWithType:(WDGradientType)type
{
    return [WDGradient gradientWithType:type stops:self.stops];
}

- (WDGradient *) gradientByRemovingStop:(WDGradientStop *)stopToRemove
{
    NSMutableArray  *remaining = [NSMutableArray array];
    
    for (WDGradientStop *stop in stops_) {
        if (stop != stopToRemove) {
            [remaining addObject:stop];
        }
    }
    
    return [self gradientWithStops:remaining];
}

- (WDGradient *) gradientWithStop:(WDGradientStop *)newStop substitutedForStop:(WDGradientStop *)replace
{
    NSMutableArray  *substituted = [NSMutableArray array];
    
    for (WDGradientStop *stop in stops_) {
        [substituted addObject:(stop == replace) ? newStop : stop];
    }
    
    return [self gradientWithStops:substituted];
}

- (WDGradient *) gradientWithStopAtRatio:(float)ratio
{
    NSMutableArray  *tempStops = [self.stops mutableCopy];
    WDGradientStop  *previous = nil;
    BOOL            added = NO;
    
    for (WDGradientStop *stop in tempStops) {
        if (stop.ratio > ratio) { // we've passed the point of insertion
            if (!previous) {
                // this new stop goes before the current initial stop
                [tempStops insertObject:[WDGradientStop stopWithColor:stop.color andRatio:ratio] atIndex:0];
                added = YES;
            } else {
                // determine where this new ratio falls between the existing stops
                float fraction = (ratio - previous.ratio) / (stop.ratio - previous.ratio);  
                WDColor *blended = [previous.color blendedColorWithFraction:fraction ofColor:stop.color];
                NSUInteger index = [tempStops indexOfObject:stop];
                
                [tempStops insertObject:[WDGradientStop stopWithColor:blended andRatio:ratio] atIndex:index];
                added = YES;
            }
            break;
        }
        previous = stop;
    }
    
    if (!added) {
        // must go after the current last stop
        WDGradientStop *lastStop = (WDGradientStop *) [tempStops lastObject];
        [tempStops addObject:[WDGradientStop stopWithColor:lastStop.color andRatio:ratio]];
    }
    
    WDGradient *result = [WDGradient gradientWithType:self.type stops:tempStops];
    return result;
}

- (WDGradient *) gradientByAddingStop:(WDGradientStop *)newStop
{
    NSMutableArray  *tempStops = [self.stops mutableCopy];
    BOOL            added =  NO;
    
    for (WDGradientStop *stop in tempStops) {
        if (stop.ratio > newStop.ratio) {
            [tempStops insertObject:newStop atIndex:[tempStops indexOfObject:stop]];
            added = YES;
            break;
        }
    }
             
    if (!added) {
        [tempStops addObject:newStop];
    }
    
    WDGradient *result = [WDGradient gradientWithType:self.type stops:tempStops];
    return result;
}

- (WDColor *) colorAtRatio:(float)ratio
{
    WDGradientStop  *previous = nil;
    
    ratio = WDClamp(0.0f, 1.0f, ratio);
    
    for (WDGradientStop *stop in stops_) {
        if (stop.ratio > ratio) { // we've passed the point of insertion
            if (!previous) {
                return stop.color;
            } else {
                float fraction = (ratio - previous.ratio) / (stop.ratio - previous.ratio);  
                return [previous.color blendedColorWithFraction:fraction ofColor:stop.color];
            }
        }
        previous = stop;
    }
    
    WDGradientStop *lastStop = (WDGradientStop *) [stops_ lastObject];
    return lastStop.color;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt32:type_ forKey:WDGradientTypeKey];
    [coder encodeObject:stops_ forKey:WDGradientStopsKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    type_ = [coder decodeInt32ForKey:WDGradientTypeKey];
    stops_ = [coder decodeObjectForKey:WDGradientStopsKey];
    
    return self;
}

- (id) copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL) isEqual:(WDGradient *)gradient
{
    if (!gradient || ![gradient isKindOfClass:[WDGradient class]]) {
        return NO;
    }
    
    // test relevant ivars in fastest to slowest order
    if (self.type != gradient.type) {
        return NO;
    }
    
    if (![self.stops isEqualToArray:gradient.stops]) {
        return NO;
    }
    
    return YES;
}

- (CGGradientRef) newGradientRef
{
    NSMutableArray  *colors = [NSMutableArray array];
    CGFloat         locations[stops_.count];
    int             ix = 0;
    
    for (WDGradientStop *stop in stops_) {
        [colors addObject:(id) [stop.color CGColor]];
        locations[ix++] = stop.ratio;
    }
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef result = CGGradientCreateWithColors(colorspace, (CFArrayRef) colors, locations);
    CGColorSpaceRelease(colorspace);
    
    return result;
}

- (CGGradientRef) gradientRef
{
    if (!gradientRef_) {
        gradientRef_ = [self newGradientRef];
    }
    
    return gradientRef_;
}

- (void) drawSwatchInRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    
    WDDrawCheckersInRect(ctx, rect, 7);
    
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, rect);
    
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    
    if (type_ == kWDRadialGradient) {
        float   width = CGRectGetWidth(rect) / 2;
        float   height = CGRectGetHeight(rect) / 2;
        float   radius = sqrt(width * width + height * height);
        
        CGContextDrawRadialGradient(ctx, [self gradientRef], WDCenterOfRect(rect), 0,  WDCenterOfRect(rect), radius, options);
    } else {
        CGContextDrawLinearGradient(ctx, [self gradientRef], rect.origin, CGPointMake(CGRectGetMaxX(rect), rect.origin.y), options);
    }
    
    CGContextRestoreGState(ctx);
}

- (void) drawEyedropperSwatchInRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    
    WDDrawCheckersInRect(ctx, rect, 7);
    
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, rect);
    
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawLinearGradient(ctx, [self gradientRef], rect.origin, CGPointMake(CGRectGetMaxX(rect), rect.origin.y), options);
    CGContextRestoreGState(ctx);
}

- (void) paintPath:(WDPath *)path inContext:(CGContextRef)ctx
{   
    WDFillTransform             *fillTransform = path.fillTransform;
    CGGradientDrawingOptions    options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path.pathRef);
    
    if (path.fillRule == kWDEvenOddFillRule) {
        CGContextEOClip(ctx);
    } else {
        CGContextClip(ctx);
    }
    
    CGContextConcatCTM(ctx, fillTransform.transform);
    
    if (type_ == kWDRadialGradient) {
        CGPoint delta = WDSubtractPoints(fillTransform.end, fillTransform.start);
        CGContextDrawRadialGradient(ctx, [self gradientRef], fillTransform.start, 0, fillTransform.start, WDMagnitude(delta), options);
    } else {
        CGContextDrawLinearGradient(ctx, [self gradientRef], fillTransform.start, fillTransform.end, options);
    }
    
    CGContextRestoreGState(ctx);
}

- (BOOL) wantsCenteredFillTransform
{
    return (self.type == kWDRadialGradient) ? YES : NO;
}

- (BOOL) transformable
{
    return YES;
}

- (BOOL) canPaintStroke
{
    return NO;
}

- (void) paintText:(WDText *)text inContext:(CGContextRef)ctx
{
    if (!text.text || text.text.length == 0) {
        return;
    }
    
    WDFillTransform             *fillTransform = text.fillTransform;
    CGGradientDrawingOptions    options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    BOOL                        didClip;
    
    CGContextSaveGState(ctx);
    [text drawTextInContext:(CGContextRef)ctx drawingMode:kCGTextClip didClip:&didClip];
    
    if (!didClip) {
        CGContextRestoreGState(ctx);
        return;
    }
    
    // apply the fill transform
    CGContextConcatCTM(ctx, fillTransform.transform);
    
    if (type_ == kWDRadialGradient) {
        CGPoint delta = WDSubtractPoints(fillTransform.end, fillTransform.start);
        CGContextDrawRadialGradient(ctx, [self gradientRef], fillTransform.start, 0, fillTransform.start, WDMagnitude(delta), options);
    } else {
        CGContextDrawLinearGradient(ctx, [self gradientRef], fillTransform.start, fillTransform.end, options);
    }
    
    CGContextRestoreGState(ctx);
}

- (WDXMLElement *) SVGElementWithID:(NSString *)unique fillTransform:(WDFillTransform *)fT
{
    WDXMLElement *gradient;
    
    if (type_ == kWDRadialGradient) {
        gradient = [WDXMLElement elementWithName:@"radialGradient"];
        [gradient setAttribute:@"cx" floatValue:fT.start.x];
        [gradient setAttribute:@"cy" floatValue:fT.start.y];
        [gradient setAttribute:@"r" floatValue:WDDistance(fT.end, fT.start)];
    } else {
        gradient = [WDXMLElement elementWithName:@"linearGradient"];
        [gradient setAttribute:@"x1" floatValue:fT.start.x];
        [gradient setAttribute:@"y1" floatValue:fT.start.y];
        [gradient setAttribute:@"x2" floatValue:fT.end.x];
        [gradient setAttribute:@"y2" floatValue:fT.end.y];
    }
    
    [gradient setAttribute:@"id" value:unique];
    [gradient setAttribute:@"gradientUnits" value:@"userSpaceOnUse"];
    [gradient setAttribute:@"gradientTransform" value:WDSVGStringForCGAffineTransform(fT.transform)];
    
    for (WDGradientStop *stop in stops_) {
        [gradient addChild:[stop SVGXMLElement]];
    }
    
    return gradient;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@: type: %d stops: %@", [super description], type_, stops_];
}

@end

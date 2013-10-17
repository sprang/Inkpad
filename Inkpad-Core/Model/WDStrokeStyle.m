//
//  WDStrokeStyle.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import "WDStrokeStyle.h"
#import "WDColor.h"
#import "WDXMLElement.h"

NSString *WDColorKey = @"WDColorKey";
NSString *WDWeightKey = @"WDWeightKey";
NSString *WDCapKey = @"WDCapKey";
NSString *WDJoinKey = @"WDJoinKey";
NSString *WDDashPatternKey = @"WDDashPatternKey";
NSString *WDStartArrowKey = @"WDStartArrowKey";
NSString *WDEndArrowKey = @"WDEndArrowKey";

@implementation WDStrokeStyle

@synthesize width = width_;
@synthesize cap = cap_;
@synthesize join = join_;
@synthesize color = color_;
@synthesize dashPattern = dashPattern_;
@synthesize startArrow = startArrow_;
@synthesize endArrow = endArrow_;

NSString * WDSVGStringForCGLineJoin(CGLineJoin join)
{
    NSString *joins[] = {@"miter", @"round", @"bevel"};
    return joins[join];
}

NSString * WDSVGStringForCGLineCap(CGLineCap cap)
{
    NSString *caps[] = {@"butt", @"round", @"square"};
    return caps[cap];
}

+ (WDStrokeStyle *) strokeStyleWithWidth:(float)width cap:(CGLineCap)cap join:(CGLineJoin)join color:(WDColor *)color
                             dashPattern:(NSArray *)dashPattern
{
    WDStrokeStyle *style = [[WDStrokeStyle alloc] initWithWidth:width
                                                            cap:cap
                                                           join:join
                                                          color:color
                                                    dashPattern:dashPattern
                                                     startArrow:nil
                                                       endArrow:nil];
    return style;
}

+ (WDStrokeStyle *) strokeStyleWithWidth:(float)width cap:(CGLineCap)cap join:(CGLineJoin)join color:(WDColor *)color
                             dashPattern:(NSArray *)dashPattern startArrow:(NSString *)startArrow endArrow:(NSString *)endArrow
{
    WDStrokeStyle *style = [[WDStrokeStyle alloc] initWithWidth:width
                                                            cap:cap
                                                           join:join
                                                          color:color
                                                    dashPattern:dashPattern
                                                     startArrow:startArrow
                                                       endArrow:endArrow];
    return style;
}

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    width_ = 1;
    cap_ = kCGLineCapRound;
    join_ = kCGLineJoinRound;
    color_ = [WDColor blackColor];
    
    return self;
}

- (id) initWithWidth:(float)width cap:(CGLineCap)cap join:(CGLineJoin)join color:(WDColor *)color
         dashPattern:(NSArray *)dashPattern startArrow:(NSString *)startArrow endArrow:(NSString *)endArrow
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    width_ = width;
    cap_ = cap;
    join_ = join;
    color_ = color;
    startArrow_ = startArrow;
    endArrow_ = endArrow;
    
    if (dashPattern && dashPattern.count) {
        dashPattern_ = dashPattern;
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:color_ forKey:WDColorKey];
    [coder encodeFloat:width_ forKey:WDWeightKey];
    [coder encodeInt32:cap_ forKey:WDCapKey];
    [coder encodeInt32:join_ forKey:WDJoinKey];
    
    if ([self hasPattern]) {
        [coder encodeObject:dashPattern_ forKey:WDDashPatternKey];
    }
    
    if (self.startArrow && ![self.startArrow isEqualToString:@"none"]) {
        [coder encodeObject:self.startArrow forKey:WDStartArrowKey];
    }
    
    if (self.endArrow && ![self.endArrow isEqualToString:@"none"]) {
        [coder encodeObject:self.endArrow forKey:WDEndArrowKey];
    }
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    width_ = [coder decodeFloatForKey:WDWeightKey]; 
    cap_ = [coder decodeInt32ForKey:WDCapKey]; 
    join_ = [coder decodeInt32ForKey:WDJoinKey]; 
    color_ = [coder decodeObjectForKey:WDColorKey];
    dashPattern_ = [coder decodeObjectForKey:WDDashPatternKey];
    startArrow_ = [coder decodeObjectForKey:WDStartArrowKey];
    endArrow_ = [coder decodeObjectForKey:WDEndArrowKey];
    
    return self; 
}
 
- (NSString *) description
{
    return [NSString stringWithFormat:@"%@: width: %f, cap: %d, join:%d, color: %@, dashPattern: %@, start arrow: %@, end arrow: %@",
            [super description], width_, cap_, join_, [color_ description], dashPattern_, startArrow_, endArrow_];
}

- (WDStrokeStyle *) adjustColor:(WDColor * (^)(WDColor *color))adjustment
{
    return [WDStrokeStyle strokeStyleWithWidth:self.width
                                           cap:self.cap
                                          join:self.join
                                         color:[self.color adjustColor:adjustment]
                                   dashPattern:self.dashPattern
                                    startArrow:self.startArrow
                                      endArrow:self.endArrow];
}

- (void) addSVGAttributes:(WDXMLElement *)element
{
    [element setAttribute:@"stroke" value:[color_ hexValue]];
    [element setAttribute:@"stroke-width" value:[NSString stringWithFormat:@"%g", width_]];
    
    if (cap_ != kCGLineCapButt) {
        [element setAttribute:@"stroke-linecap" value:WDSVGStringForCGLineCap(cap_)];
    }
    
    if (join_ != kCGLineJoinMiter) {
        [element setAttribute:@"stroke-linejoin" value:WDSVGStringForCGLineJoin(join_)];
    }
    
    if ([color_ alpha] != 1) {
        [element setAttribute:@"stroke-opacity" floatValue:[color_ alpha]];
    }
    
    if (dashPattern_) {
        NSMutableArray  *dashes = [dashPattern_ mutableCopy];
        NSMutableString *svgPattern = [NSMutableString string];
        
        while ([[dashes lastObject] intValue] == 0) {
            [dashes removeLastObject];
        }
        
        BOOL first = YES;
        for (NSNumber *number in dashes) {
            if (!first) {
                [svgPattern appendString:@","];
            }
            first = NO;
            [svgPattern appendString:[number stringValue]];
        }
        
        [element setAttribute:@"stroke-dasharray" value:svgPattern];
    }
}

- (BOOL) isEqual:(WDStrokeStyle *)stroke
{
    if (stroke == self) {
        return YES;
    }
    
    if (![stroke isKindOfClass:[WDStrokeStyle class]]) {
        return NO;
    }
    
    return (width_ == stroke.width &&
            cap_ == stroke.cap &&
            join_ == stroke.join &&
            [color_ isEqual:stroke.color] &&
            [dashPattern_ isEqual:stroke.dashPattern] &&
            [startArrow_ isEqualToString:stroke.startArrow] &&
            [endArrow_ isEqualToString:stroke.endArrow]);
}

- (void) randomize
{
    color_ = [WDColor randomColor];
    width_ = random() % 100 / 10;
    cap_ = kCGLineCapRound;
    join_ = kCGLineJoinRound;
}

- (BOOL) willRender
{
    return (color_ && (color_.alpha > 0) && width_ > 0);
}

- (BOOL) isNullStroke
{
    if (!color_ && !dashPattern_ && !width_ && !cap_ && !join_) {
        return YES;
    }
    
    if (width_ == 0) {
        return YES;
    }

    return NO;
}

- (BOOL) hasPattern
{
    if (!dashPattern_) {
        return NO;
    }
    
    float sum = 0;
    for (NSNumber *number in dashPattern_) {
        sum += [number floatValue];
    }
    
    return (sum > 0) ? YES : NO;
}

- (BOOL) hasArrow
{
    return (startArrow_ || endArrow_) ? YES : NO;
}

- (void) applyPatternInContext:(CGContextRef)ctx
{
    NSMutableArray *dashes = [dashPattern_ mutableCopy];
    
    while ([[dashes lastObject] intValue] == 0) {
        [dashes removeLastObject];
    }
    
    if (dashes.count % 2 == 1) {
        NSArray *repeat = [dashes copy];
        [dashes addObjectsFromArray:repeat];
    }
    
    CGFloat lengths[dashes.count];
    int i = 0;
    for (NSNumber *number in dashes) {
        lengths[i] = [number floatValue];
        if ((cap_ != kCGLineCapRound) && (lengths[i] == 0)) {
            lengths[i] = 0.1;
        }
        i++;
    }
    
    CGContextSetLineDash(ctx, 0.0f, lengths, dashes.count);
}

- (void) applyInContext:(CGContextRef)ctx
{
    if (![self willRender]) {
        return;
    }
    
    CGContextSetLineWidth(ctx, width_);
    CGContextSetLineCap(ctx, cap_);
    CGContextSetLineJoin(ctx, join_);
    CGContextSetStrokeColorWithColor(ctx, [color_ CGColor]);
    
    if ([self hasPattern]) {
        [self applyPatternInContext:ctx];
    } else {
        // turn off dashing
        CGContextSetLineDash(ctx, 0.0f, NULL, 0);
    }
}

- (id) copyWithZone:(NSZone *)zone
{
    return self;
}

@end

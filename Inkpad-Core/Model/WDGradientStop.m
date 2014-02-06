//
//  WDGradientStop.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2000-2013 Steve Sprang
//

#import "WDGradientStop.h"
#import "WDColor.h"
#import "WDUtilities.h"
#import "WDXMLElement.h"

NSString *WDStopRatioKey = @"WDStopRatioKey";
NSString *WDStopColorKey = @"WDStopColorKey";


@implementation WDGradientStop

@synthesize ratio = ratio_;
@synthesize color = color_;

+ (WDGradientStop *) stopWithColor:(WDColor *)color andRatio:(float)ratio
{
    WDGradientStop *stop = [[WDGradientStop alloc] initWithColor:color andRatio:ratio];
    return stop;
}

- (id) initWithColor:(WDColor *)color andRatio:(float)ratio
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    // makes sure we won't end up with a nil color
    color_ = color ?: [WDColor blackColor];
    ratio_ = WDClamp(0.0f, 1.0f, ratio);
    
    return self;
}

- (NSComparisonResult) compare:(WDGradientStop *)stop
{
    if (self.ratio < stop.ratio) {
        return NSOrderedAscending;
    } else if (self.ratio > stop.ratio) {
        return NSOrderedDescending;
    }
    
    return NSOrderedSame;
}

- (WDGradientStop *) stopWithRatio:(float)ratio
{
    return [WDGradientStop stopWithColor:self.color andRatio:ratio];
}

- (WDGradientStop *) stopWithColor:(WDColor *)color
{
    return [WDGradientStop stopWithColor:color andRatio:self.ratio];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeFloat:ratio_ forKey:WDStopRatioKey];
    [coder encodeObject:color_ forKey:WDStopColorKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    ratio_ = [coder decodeFloatForKey:WDStopRatioKey];
    color_ = [coder decodeObjectForKey:WDStopColorKey]; 
    
    return self; 
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@: ratio: %f color: %@", [super description], ratio_, [color_ description]];
}

- (BOOL) isEqual:(WDGradientStop *)stop
{
    // test equality for each ivar, fastest to slowest
    if (self.ratio != stop.ratio) {
        return NO;
    }
    
    if (![self.color isEqual:stop.color]) {
        return NO;
    }
    
    return YES;
}

- (WDXMLElement *) SVGXMLElement
{
    WDXMLElement *stop = [WDXMLElement elementWithName:@"stop"];
    [stop setAttribute:@"offset" value:[NSString stringWithFormat:@"%g", ratio_]];
    [stop setAttribute:@"stop-color" value:color_.hexValue];
    
    if (color_.alpha != 1.0) {
        [stop setAttribute:@"stop-opacity" value:[NSString stringWithFormat:@"%g", color_.alpha]];
    }
    
    return stop;
}

@end

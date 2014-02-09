//
//  WDDynamicGuide.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import "WDCanvas.h"
#import "WDColor.h"
#import "WDDynamicGuide.h"
#import "WDGLUtilities.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

//
// WDExtent
//

@implementation WDExtent

+ (WDExtent *) extentWithMin:(double)min max:(double)max
{
    WDExtent *extent = [[WDExtent alloc] init];
    
    extent.min = min;
    extent.max = max;
    
    return extent;
}

- (BOOL) isEqual:(WDExtent *)object
{
    if (!object || ![object isKindOfClass:[WDExtent class]]) {
        return NO;
    }
    
    return (self.min == object.min) && (self.max == object.max);
}

- (NSUInteger)hash {
    return [[NSNumber numberWithDouble:(self.min + self.max)] hash];
}

@end

//
// WDDynamicGuide
//

@implementation WDDynamicGuide

+ (WDDynamicGuide *) verticalGuideWithOffset:(double)offset
{
    WDDynamicGuide *guide = [[WDDynamicGuide alloc] initWithOffset:offset];
    guide.vertical = YES;
    return guide;
}

+ (WDDynamicGuide *) horizontalGuideWithOffset:(double)offset
{
    return [[WDDynamicGuide alloc] initWithOffset:offset];
}

- (id) initWithOffset:(double)offset
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    self.offset = offset;
    self.extents = [NSMutableSet set];
    
    return self;
}

- (NSString *) description
{
    NSString *orientation = self.vertical ? @"vertical" : @"horizontal";
    return [NSString stringWithFormat:@"%@: %g; %@", [super description], self.offset, orientation];
}

- (void) addExtent:(WDExtent *)extent
{
    if (self.extents.count == 0) {
        self.minExtent = extent.min;
        self.maxExtent = extent.max;
    } else {
        self.minExtent = MIN(extent.min, self.minExtent);
        self.maxExtent = MAX(extent.max, self.maxExtent);
    }
    
    [self.extents addObject:extent];
}

- (void) addExtentsFromSet:(NSSet *)extents
{
    for (WDExtent *extent in extents) {
        [self addExtent:extent];
    }
}

+ (void) generateGuidesForBoundingBox:(CGRect)bbox horizontalGuides:(NSMutableArray *)horizontal verticalGuides:(NSMutableArray *)vertical
{
    WDDynamicGuide *guide;
    
    CGFloat minX = CGRectGetMinX(bbox);
    CGFloat midX = CGRectGetMidX(bbox);
    CGFloat maxX = CGRectGetMaxX(bbox);
    CGFloat minY = CGRectGetMinY(bbox);
    CGFloat midY = CGRectGetMidY(bbox);
    CGFloat maxY = CGRectGetMaxY(bbox);
    
    WDExtent *verticalExtent = [WDExtent extentWithMin:minY max:maxY];
    WDExtent *horizontalExtent = [WDExtent extentWithMin:minX max:maxX];
    
    CGFloat xValues[] = {minX, midX, maxX};
    CGFloat yValues[] = {minY, midY, maxY};
    
    for (int i = 0; i < 3; i++) {
        // horizontal guides
        guide = [WDDynamicGuide horizontalGuideWithOffset:xValues[i]];
        [guide addExtent:verticalExtent];
        [horizontal addObject:guide];
        
        // vertical guides
        guide = [WDDynamicGuide verticalGuideWithOffset:yValues[i]];
        [guide addExtent:horizontalExtent];
        [vertical addObject:guide];
    }
}

- (NSComparisonResult) compare:(WDDynamicGuide *)guide
{
    return [@(self.offset) compare:@(guide.offset)];
}

- (void) render:(WDCanvas *)canvas
{
    CGPoint     a, b;
    float       outset = 10.0f / canvas.viewScale;
    float       frameHeight = CGRectGetHeight(canvas.frame);
    
    glLineWidth([UIScreen mainScreen].scale);
    glColor4f(0, 118.0 / 255, 1, 1);
    
    for (WDExtent *extent in self.extents) {
        if (self.isVertical) {
            a.y = b.y = self.offset;
            a.x = extent.min - outset;
            b.x = extent.max + outset;
        } else {
            a.x = b.x = self.offset;
            a.y = extent.min - outset;
            b.y = extent.max + outset;
        }
        
        // convert from document space to GL screen space
        a = [canvas convertPointFromDocumentSpace:a];
        b = [canvas convertPointFromDocumentSpace:b];
        
        // flip the y coordinate
        a.y = frameHeight - a.y;
        b.y = frameHeight - b.y;
        
        WDGLLineFromPointToPoint(a, b);
    }
    
    // put it back the way we found it
    glLineWidth(1);
}

@end

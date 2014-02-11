//
//  WDDynamicGuide.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import <Foundation/Foundation.h>

@class WDCanvas;

//
// WDExtent
//
@interface WDExtent : NSObject
@property (nonatomic) double min;
@property (nonatomic) double max;

+ (WDExtent *) extentWithMin:(double)min max:(double)max;
@end

//
// WDDynamicGuide
//

static NSComparator guideCompare = ^(id a, id b){
    return [a compare:b];
};

@interface WDDynamicGuide : NSObject

// the position of the guide
@property (nonatomic) double offset;

// contains an extent for every object aligned to this guide
@property (nonatomic) NSMutableSet *extents;

// the min/max of all the extents
@property (nonatomic) double minExtent;
@property (nonatomic) double maxExtent;

@property (nonatomic, getter=isVertical) BOOL vertical;

// horizontal guides align objects horizontally, but somewhat confusingly, they render as vertical lines
+ (WDDynamicGuide *) horizontalGuideWithOffset:(double)offset;

// vertical guides align objects vertically (but render as horizontal lines)
+ (WDDynamicGuide *) verticalGuideWithOffset:(double)offset;

+ (void) generateGuidesForBoundingBox:(CGRect)bbox
                     horizontalGuides:(NSMutableArray *)horizontal
                       verticalGuides:(NSMutableArray *)vertical;

- (void) addExtent:(WDExtent *)extent;
- (void) addExtentsFromSet:(NSSet *)extents;

- (void) render:(WDCanvas *)canvas;

@end

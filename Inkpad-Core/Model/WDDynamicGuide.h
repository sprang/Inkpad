//
//  WDDynamicGuide.h
//  Inkpad
//
//  Created by Steve Sprang on 2/7/14.
//  Copyright (c) 2014 Taptrix, Inc. All rights reserved.
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

+ (WDDynamicGuide *) verticalGuideWithOffset:(double)offset;
+ (WDDynamicGuide *) horizontalGuideWithOffset:(double)offset;

+ (void) generateGuidesForBoundingBox:(CGRect)bbox
                     horizontalGuides:(NSMutableArray *)horizontal
                       verticalGuides:(NSMutableArray *)vertical;

- (void) addExtent:(WDExtent *)extent;
- (void) addExtentsFromSet:(NSSet *)extents;

- (void) render:(WDCanvas *)canvas;

@end

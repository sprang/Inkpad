//
//  WDDynamicGuideController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import "WDCanvas.h"
#import "WDDrawingController.h"
#import "WDDynamicGuide.h"
#import "WDDynamicGuideController.h"
#import "WDUtilities.h"

const float kDynamicGuideSnappingTolerance = 10.0f;


@implementation WDDynamicGuideController

- (id) initWithDrawingController:(WDDrawingController *)drawingController
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    _drawingController = drawingController;
    _verticalGuides = [NSMutableArray array];
    _horizontalGuides = [NSMutableArray array];
    
    return self;
}

#pragma mark - Guide Lifecycle

- (void) beginGuideOperation
{
    if (_generatedGuides) {
        return;
    }
    
    NSMutableArray *horizontal = [NSMutableArray array];
    NSMutableArray *vertical = [NSMutableArray array];
    
    // add guides for the canvas itself
    [WDDynamicGuide generateGuidesForBoundingBox:self.drawingController.drawing.bounds
                                horizontalGuides:horizontal verticalGuides:vertical];
    
    // add guides for all unselected drawing elements
    for (WDElement *element in [self.drawingController guideGeneratingObjects]) {
        [WDDynamicGuide generateGuidesForBoundingBox:element.bounds
                                    horizontalGuides:horizontal verticalGuides:vertical];
    }
    
    // add guides for the current selection bounds
    if (self.drawingController.selectedObjects.count > 0) {
        [WDDynamicGuide generateGuidesForBoundingBox:self.drawingController.selectionBounds
                                    horizontalGuides:horizontal verticalGuides:vertical];
    }
    
    [self.horizontalGuides removeAllObjects];
    for (WDDynamicGuide *guide in horizontal) {
        [self insertGuide:guide array:self.horizontalGuides];
    }
    
    [self.verticalGuides removeAllObjects];
    for (WDDynamicGuide *guide in vertical) {
        [self insertGuide:guide array:self.verticalGuides];
    }
    
    _generatedGuides = YES;
}

- (void) endGuideOperation
{
    [self.verticalGuides removeAllObjects];
    [self.horizontalGuides removeAllObjects];
    
    _generatedGuides = NO;
}

#pragma mark -  Adding and Querying Guides

- (double) deltaForGuide:(WDDynamicGuide *)guide array:(NSArray *)guides
{
    NSUInteger nearIx = [guides indexOfObject:guide
                                inSortedRange:NSMakeRange(0, guides.count)
                                      options:NSBinarySearchingInsertionIndex
                              usingComparator:guideCompare];
    
    double leftDelta = MAXFLOAT;
    double rightDelta = MAXFLOAT;
    
    if (nearIx > 0) { // make sure there is a left guide
        NSUInteger leftIx = nearIx - 1;
        WDDynamicGuide *left = guides[leftIx];
        leftDelta = left.offset - guide.offset;
    }
    
    if (nearIx < guides.count) { // make sure there is a right guide
        WDDynamicGuide *right = guides[nearIx];
        rightDelta = right.offset - guide.offset;
    }
    
    return (fabs(leftDelta) < fabs(rightDelta)) ? leftDelta : rightDelta;
}

- (WDDynamicGuide *) findCoincidentGuide:(WDDynamicGuide *)guide array:(NSArray *)guides
{
    NSUInteger nearIx = [guides indexOfObject:guide
                                inSortedRange:NSMakeRange(0, guides.count)
                                      options:NSBinarySearchingInsertionIndex
                              usingComparator:guideCompare];
    
    double      leftDelta = MAXFLOAT;
    double      rightDelta = MAXFLOAT;
    NSUInteger  leftIx = nearIx - 1;
    
    if (nearIx > 0) { // make sure there is a left guide
        WDDynamicGuide *left = guides[leftIx];
        leftDelta = left.offset - guide.offset;
    }
    
    if (nearIx < guides.count) { // make sure there is a right guide
        WDDynamicGuide *right = guides[nearIx];
        rightDelta = right.offset - guide.offset;
    }
    
    if (fabs(leftDelta) < fabs(rightDelta)) {
        if (fabs(leftDelta) < 1.0e-3) {
            return guides[leftIx];
        }
    } else if (fabs(rightDelta) < 1.0e-3) {
        return guides[nearIx];
    }
    
    return nil;
}

- (void) insertGuide:(WDDynamicGuide *)guide array:(NSMutableArray *)guides
{
    WDDynamicGuide *coincident = [self findCoincidentGuide:guide array:guides];
    
    if (coincident) {
        [coincident.extents addObject:[guide.extents anyObject]];
    } else {
        NSUInteger insertIx = [guides indexOfObject:guide
                                      inSortedRange: NSMakeRange(0, guides.count)
                                            options:NSBinarySearchingInsertionIndex
                                    usingComparator:guideCompare];
        
        [guides insertObject:guide atIndex:insertIx];
    }
}

#pragma mark - Finding Snapped Guides

- (NSArray *) snappedGuidesForPoint:(CGPoint)pt
{
    NSMutableArray *snapped = [NSMutableArray array];
    
    WDDynamicGuide *horizontal = [WDDynamicGuide horizontalGuideWithOffset:pt.x];
    [horizontal addExtent:[WDExtent extentWithMin:pt.y max:pt.y]];
    
    WDDynamicGuide *vertical = [WDDynamicGuide verticalGuideWithOffset:pt.y];
    [vertical addExtent:[WDExtent extentWithMin:pt.x max:pt.x]];
    
    WDDynamicGuide *found = [self findCoincidentGuide:horizontal array:self.horizontalGuides];
    if (found) {
        [horizontal addExtentsFromSet:found.extents];
        [snapped addObject:horizontal];
    }
    
    found = [self findCoincidentGuide:vertical array:self.verticalGuides];
    if (found) {
        [vertical addExtentsFromSet:found.extents];
        [snapped addObject:vertical];
    }
    
    return snapped;
}

- (NSArray *) snappedGuidesForRect:(CGRect)snapRect
{
    NSMutableArray *snapped = [NSMutableArray array];
    NSMutableArray *horizontal = [NSMutableArray array];
    NSMutableArray *vertical = [NSMutableArray array];
    
    // generate guides for the offset selection bounds
    [WDDynamicGuide generateGuidesForBoundingBox:snapRect horizontalGuides:horizontal verticalGuides:vertical];
    
    for (WDDynamicGuide *test in horizontal) {
        WDDynamicGuide *found = [self findCoincidentGuide:test array:self.horizontalGuides];
        if (found) {
            [test addExtentsFromSet:found.extents];
            [snapped addObject:test];
        }
    }
    
    for (WDDynamicGuide *test in vertical) {
        WDDynamicGuide *found = [self findCoincidentGuide:test array:self.verticalGuides];
        if (found) {
            [test addExtentsFromSet:found.extents];
            [snapped addObject:test];
        }
    }
    
    return snapped;
}

#pragma mark - Calculating Offsets

- (CGPoint) adjustedPointForGuides:(CGPoint)pt viewScale:(float)viewScale
{
    double      hDelta, vDelta;
    double      tolerance = (kDynamicGuideSnappingTolerance / viewScale);
    
    WDDynamicGuide *horizontal = [WDDynamicGuide horizontalGuideWithOffset:pt.x];
    WDDynamicGuide *vertical = [WDDynamicGuide verticalGuideWithOffset:pt.y];
    
    hDelta = [self deltaForGuide:horizontal array:self.horizontalGuides];
    hDelta = fabs(hDelta) > tolerance ? 0 : hDelta;
    
    vDelta = [self deltaForGuide:vertical array:self.verticalGuides];
    vDelta = fabs(vDelta) > tolerance ? 0 : vDelta;
    
    return WDAddPoints(CGPointMake(hDelta, vDelta), pt);
}

- (CGPoint) offsetSelectionForGuides:(CGPoint)originalDelta viewScale:(float)viewScale
{
    CGRect          selectionBounds = CGRectOffset([self.drawingController selectionBounds], originalDelta.x, originalDelta.y);
    double          hDelta, vDelta, currentSmallest = MAXFLOAT;
    double          tolerance = (kDynamicGuideSnappingTolerance / viewScale);
    
    NSMutableArray *horizontal = [NSMutableArray array];
    NSMutableArray *vertical = [NSMutableArray array];
    
    // generate guides for the offset selection bounds
    [WDDynamicGuide generateGuidesForBoundingBox:selectionBounds horizontalGuides:horizontal verticalGuides:vertical];
    
    // for each test guide, find the nearest real guide and compute a delta
    for (WDDynamicGuide *test in horizontal) {
        hDelta = [self deltaForGuide:test array:self.horizontalGuides];
        if (fabs(hDelta) < fabs(currentSmallest)) {
            currentSmallest = hDelta;
        }
    }
    hDelta = fabs(currentSmallest) > tolerance ? 0 : currentSmallest;
    
    currentSmallest = MAXFLOAT;
    for (WDDynamicGuide *test in vertical) {
        vDelta = [self deltaForGuide:test array:self.verticalGuides];
        if (fabs(vDelta) < fabs(currentSmallest)) {
            currentSmallest = vDelta;
        }
    }
    vDelta = fabs(currentSmallest) > tolerance ? 0 : currentSmallest;
    
    return WDAddPoints(CGPointMake(hDelta, vDelta), originalDelta);
}

@end

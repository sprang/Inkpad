//
//  WDSelectionTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDAbstractPath.h"
#import "WDBezierNode.h"
#import "WDCanvas.h"
#import "WDCanvasController.h"
#import "WDCompoundPath.h"
#import "WDDynamicGuide.h"
#import "WDDrawingController.h"
#import "WDFillTransform.h"
#import "WDPath.h"
#import "WDPropertyManager.h"
#import "WDSelectionTool.h"
#import "WDTextPath.h"
#import "WDUtilities.h"

const float kDynamicGuideSnappingTolerance = 10.0f;

@implementation WDSelectionTool

@synthesize groupSelect = groupSelect_;

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    transform_ = CGAffineTransformIdentity;
    horizontalGuides_ = [NSMutableArray array];
    verticalGuides_ = [NSMutableArray array];
    
    return self;
}

- (NSString *) iconName
{
    return (self.groupSelect ? @"groupSelect.png" : @"select.png");
}

- (void) flagsChangedInCanvas:(WDCanvas *)canvas
{
    if (!marqueeMode_) {
        return;
    }
    
    CGRect selectionRect;
    CGPoint currentPt = self.previousEvent.location;
    CGPoint initialPt = self.initialEvent.location;
    
    if (self.flags & WDToolOptionKey || self.flags & WDToolSecondaryTouch) {
        CGPoint delta = WDSubtractPoints(initialPt, currentPt);
        selectionRect = WDRectWithPoints(WDAddPoints(initialPt, delta), WDSubtractPoints(initialPt, delta));
    } else {
        selectionRect = WDRectWithPoints(initialPt, currentPt);
    }
    
    canvas.marquee = [NSValue valueWithCGRect:selectionRect];
    [canvas.drawingController selectObjectsInRect:selectionRect];
}

- (void) selectWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{
    WDDrawingController *controller = canvas.drawingController;
    
    activeNode_ = nil;
    activeTextHandle_ = kWDEther;
    activeGradientHandle_ = kWDEther;
    transformingNodes_ = NO;
    transformingHandles_ = NO;
    convertingNode_ = NO;
    transformingGradient_ = NO;
    transformingTextKnobs_ = NO;
    transformingTextPathStartKnob_ = NO;
    lastTappedObject_ = nil;
    
    WDPickResult *result = [controller objectUnderPoint:event.location viewScale:canvas.viewScale];
    
    if (result.type == kWDEther) {
        // didn't hit anything: marquee mode!
        [controller selectNone:nil];
        controller.propertyManager.ignoreSelectionChanges = YES;
        marqueeMode_ = YES;
        return;
    }
    
    WDElement *element = result.element;
    
    if (![controller isSelected:element]) {
        WDPath *path = nil;
        
        if ([element isKindOfClass:[WDPath class]]) {
            path = (WDPath *) element;
        }
        
        if (!path || !path.superpath || (path.superpath && ![controller isSelected:path.superpath])) {
            if (!self.groupSelect) {
                [controller selectNone:nil];
            }
            [controller selectObject:element];
        } else if (path && path.superpath && [controller isSelected:path.superpath] && ![controller singleSelection]) {
            lastTappedObject_ = path.superpath;
            objectWasSelected_ = YES;
        }
    } else if ([controller singleSelection]) {
        // we have a single selection, and the hit element is already selected... it must be the single selection
       
        if ([element isKindOfClass:[WDPath class]] && result.node) {
            nodeWasSelected_ = result.node.selected;
            activeNode_ = result.node;
            
            if (!nodeWasSelected_) {
                if (!self.groupSelect) {
                    // only allow one node to be selected at a time
                    [controller deselectAllNodes];
                }
                [controller selectNode:result.node];
            }
            
            if (event.count == 2) {
                // convert node mode, start transforming handles in pure reflection mode
                pointToMove_ = (result.type == kWDAnchorPoint) ? kWDOutPoint : result.type;
                pointToConvert_ = result.type;
                originalReflectionMode_ = WDReflect;
                transformingHandles_ = YES;
                convertingNode_ = YES;
            } else if (result.type == kWDInPoint || result.type == kWDOutPoint) {
                pointToMove_ = result.type;
                originalReflectionMode_ = activeNode_.reflectionMode;
                transformingHandles_ = YES;
            } else {
                // we're dragging a node, we should treat it as the snap point
                self.initialEvent.snappedLocation = result.node.anchorPoint;
                transformingNodes_ = YES;
            }
        } else if ([element isKindOfClass:[WDPath class]] && result.type == kWDEdge) {
            // only allow one node to be selected at a time
            [controller deselectAllNodes];
            
            if (event.count == 2 && [element conformsToProtocol:@protocol(WDTextRenderer)]) {
                [canvas.controller editTextObject:(WDText *)element selectAll:NO];
            }
        } else if ([element isKindOfClass:[WDStylable class]] && (result.type == kWDFillEndPoint || result.type == kWDFillStartPoint)) {
            activeGradientHandle_ = result.type;
            transformingGradient_ = YES;
        } else if ([element isKindOfClass:[WDTextPath class]] && (result.type == kWDTextPathStartKnob)) {
            activeTextPath_ = (WDTextPath *) element;
            transformingTextPathStartKnob_ = YES;
            [activeTextPath_ cacheOriginalStartOffset];
        } else if ([element isKindOfClass:[WDAbstractPath class]]) {
            if (result.type == kWDObjectFill) {
                [controller deselectAllNodes];
                
                if (event.count == 2 && [element conformsToProtocol:@protocol(WDTextRenderer)]) {
                    [canvas.controller editTextObject:(WDText *)element selectAll:NO];
                }
            }
        } else if ([element isKindOfClass:[WDText class]]) {
            if (event.count == 2) {
                [canvas.controller editTextObject:(WDText *)element selectAll:NO];
            } else
                if (result.type == kWDLeftTextKnob || result.type == kWDRightTextKnob) {
                activeTextHandle_ = result.type;
                transformingTextKnobs_ = YES;
                [(WDText *)element cacheTransformAndWidth];
            }
        }
    } else {
        lastTappedObject_ = element;
        objectWasSelected_ = [controller isSelected:result.element];
    }
}

- (void) beginWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{
    [self selectWithEvent:event inCanvas:canvas];

    // reset the transform
    transform_ = CGAffineTransformIdentity;
    generatedGuides_ = NO;
}

- (void) moveWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{
    CGPoint initialPt = self.initialEvent.location;
    CGPoint initialSnapped = self.initialEvent.snappedLocation;
    CGPoint currentPt = event.location;
    CGPoint snapped = event.snappedLocation;
    CGPoint delta;
    
    if (marqueeMode_) {
        CGRect selectionRect;
        
        if (self.flags & WDToolSecondaryTouch || self.flags & WDToolOptionKey) {
            delta = WDSubtractPoints(initialPt, currentPt);
            selectionRect = WDRectWithPoints(WDAddPoints(initialPt, delta), WDSubtractPoints(initialPt, delta));
        } else {
            selectionRect = WDRectWithPoints(initialPt, currentPt);
       }
        
        canvas.marquee = [NSValue valueWithCGRect:selectionRect];
        [canvas.drawingController selectObjectsInRect:selectionRect];
    }  else if (transformingNodes_) {
        canvas.transforming = canvas.transformingNode = YES;
        delta = WDSubtractPoints(snapped, initialSnapped);
    
        if (self.flags & WDToolShiftKey || self.flags & WDToolSecondaryTouch) {
            delta = WDConstrainPoint(delta);
        }
        
        transform_ = CGAffineTransformMakeTranslation(delta.x, delta.y);
        [canvas transformSelection:transform_];
    } else if (transformingHandles_) {
        canvas.transforming = canvas.transformingNode = YES;
        
        WDPath *path = (WDPath *) [canvas.drawingController singleSelection];
        WDBezierNodeReflectionMode reflect = (self.flags & WDToolOptionKey || self.flags & WDToolSecondaryTouch ? WDIndependent : originalReflectionMode_);
        
        replacementNode_ = [activeNode_ moveControlHandle:(int)pointToMove_ toPoint:snapped reflectionMode:reflect];
        replacementNode_.selected = YES; 
        
        NSMutableArray *newNodes = [NSMutableArray array];
        
        for (WDBezierNode *node in path.nodes) {
            if (node == activeNode_) {
                [newNodes addObject:replacementNode_];
            } else {
                [newNodes addObject:node];
            }
        }
        
        path.displayNodes = newNodes;
        path.displayClosed = path.closed;
        [canvas invalidateSelectionView];
    } else if (transformingGradient_) {
        canvas.transforming = YES;
        canvas.transformingNode = YES;
        
        WDPath *path = (WDPath *) [canvas.drawingController.selectedObjects anyObject];
        if (activeGradientHandle_ == kWDFillStartPoint) {
            path.displayFillTransform = [path.fillTransform transformWithTransformedStart:snapped];
        } else {
            path.displayFillTransform = [path.fillTransform transformWithTransformedEnd:snapped];
        }
        
        [canvas invalidateSelectionView];
    } else if (transformingTextKnobs_) {
        canvas.transforming = YES;
        
        WDText *text = (WDText *) [canvas.drawingController singleSelection];
        [text moveHandle:activeTextHandle_ toPoint:snapped];
        
        [canvas invalidateSelectionView];
    } else if (transformingTextPathStartKnob_) {
        WDTextPath *path = (WDTextPath *) [canvas.drawingController.selectedObjects anyObject];
        [path moveStartKnobToNearestPoint:currentPt]; 
        [canvas invalidateSelectionView];
    } else { 
        // transform selected
        canvas.transforming = YES;
        canvas.transformingNode = [canvas.drawingController selectedNodes].count;
        
        delta = WDSubtractPoints(currentPt, initialSnapped);
        
        if (self.flags & WDToolShiftKey || self.flags & WDToolSecondaryTouch) {
            delta = WDConstrainPoint(delta);
        }
        
        BOOL snapToGuides = [canvas.drawing dynamicGuides];
        if (snapToGuides && !generatedGuides_) {
            [self generateGuides:canvas.drawingController];
        }
        
        // grid snapping overrides guide snapping
        if ([canvas.drawing snapFlags] & kWDSnapGrid) {
            delta = [self offsetSelection:delta inCanvas:canvas];
        } else if (snapToGuides) {
            delta = [self offsetSelectionForGuides:delta inCanvas:canvas];
        }
        
        if (snapToGuides) {
            // find guides that are snapped to the result
            CGRect snapRect = CGRectOffset([canvas.drawingController selectionBounds], delta.x, delta.y);
            canvas.dynamicGuides = [self snappedGuides:snapRect];
        }
        
        transform_ = CGAffineTransformMakeTranslation(delta.x, delta.y);
        [canvas transformSelection:transform_];
    }
}

- (void) endWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{
    if (marqueeMode_) {
        marqueeMode_ = NO;
        canvas.marquee = nil;
        canvas.drawingController.propertyManager.ignoreSelectionChanges = NO;
        return;
    }
    
    canvas.transforming = canvas.transformingNode = NO;
    
    if (transformingGradient_) {
        if (self.moved) {
            WDPath *path = ((WDPath *) [canvas.drawingController singleSelection]);
            
            path.fillTransform = path.displayFillTransform;
            path.displayFillTransform = nil;
        }
    } else if (transformingNodes_) {
        if (!self.moved && nodeWasSelected_) {
            [canvas.drawingController deselectNode:activeNode_];;
        } else if (self.moved) {
            // apply the transform to the drawing
            [canvas.drawingController transformSelection:transform_];
            [canvas transformSelection:CGAffineTransformIdentity];
            transform_ = CGAffineTransformIdentity;
        }
    } else if (convertingNode_ && !self.moved) {
        WDPath *path = ((WDPath *) [canvas.drawingController singleSelection]);
        
        WDBezierNode *node = [path convertNode:activeNode_ whichPoint:(int)pointToConvert_];
        [canvas.drawingController deselectNode:activeNode_];
        [canvas.drawingController selectNode:node];
    } else if (transformingHandles_ && replacementNode_) {
        WDPath *path = ((WDPath *) [canvas.drawingController singleSelection]);
        path.displayNodes = nil;
        NSMutableArray *newNodes = [NSMutableArray array];
        
        for (WDBezierNode *node in path.nodes) {
            if (node == activeNode_) {
                [newNodes addObject:replacementNode_];
            } else {
                [newNodes addObject:node];
            }
        }
        
        [canvas.drawingController selectNode:replacementNode_];
        replacementNode_ = nil;
        path.nodes = newNodes;
    }  else if (transformingTextPathStartKnob_) {
        [activeTextPath_ registerUndoWithCachedStartOffset];
        activeTextPath_ = nil;
    } else if (transformingTextKnobs_) {
        WDText *text = (WDText *) [canvas.drawingController singleSelection];
        [text registerUndoWithCachedTransformAndWidth];
    } else {
        if (self.moved) {
            // apply the transform to the drawing
            [canvas.drawingController transformSelection:transform_];
            [canvas transformSelection:CGAffineTransformIdentity];
            transform_ = CGAffineTransformIdentity;
        } else if (self.groupSelect && lastTappedObject_ && objectWasSelected_) {
            [canvas.drawingController deselectObject:lastTappedObject_];
        }
        
        // clear guide containers
        [horizontalGuides_ removeAllObjects];
        [verticalGuides_ removeAllObjects];
        canvas.dynamicGuides = nil;
    }
}

#pragma mark - Grid Snapping

- (NSValue *) snapCorner:(CGPoint)pt inCanvas:(WDCanvas *)canvas
{
    WDPickResult *result = [canvas.drawingController snappedPoint:pt viewScale:canvas.viewScale snapFlags:kWDSnapGrid];
    
    if (result.snapped) {
        CGPoint delta = WDSubtractPoints(result.snappedPoint, pt);
        return [NSValue valueWithCGPoint:delta];
    }
    
    return nil;
}

- (CGPoint) offsetSelection:(CGPoint)originalDelta inCanvas:(WDCanvas *)canvas
{
    CGRect          selectionBounds = CGRectOffset([canvas.drawingController selectionBounds], originalDelta.x, originalDelta.y);
    NSMutableArray  *deltas = [NSMutableArray array];
    CGPoint         delta;
    
    // snap each corner and see which has the smallest delta
    
    CGPoint ul = CGPointMake(CGRectGetMinX(selectionBounds), CGRectGetMinY(selectionBounds));
    [deltas addObject:[self snapCorner:ul inCanvas:canvas]];
    
    CGPoint ur = CGPointMake(CGRectGetMaxX(selectionBounds), CGRectGetMinY(selectionBounds));
    [deltas addObject:[self snapCorner:ur inCanvas:canvas]];
    
    CGPoint lr = CGPointMake(CGRectGetMaxX(selectionBounds), CGRectGetMaxY(selectionBounds));
    [deltas addObject:[self snapCorner:lr inCanvas:canvas]];
    
    CGPoint ll = CGPointMake(CGRectGetMinX(selectionBounds), CGRectGetMaxY(selectionBounds));
    [deltas addObject:[self snapCorner:ll inCanvas:canvas]];
    
    delta = [deltas[0] CGPointValue];
    for (NSValue *value in deltas) {
        CGPoint test = [value CGPointValue];
        if (WDDistance(test, CGPointZero) < WDDistance(delta, CGPointZero)) {
            delta = test;
        }
    }
    
    return WDAddPoints(delta, originalDelta);
}

#pragma mark - Dynamic Guides

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

- (NSArray *) snappedGuides:(CGRect)snapRect
{
    NSMutableArray *snapped = [NSMutableArray array];
    NSMutableArray *horizontal = [NSMutableArray array];
    NSMutableArray *vertical = [NSMutableArray array];
    
    // generate guides for the offset selection bounds
    [WDDynamicGuide generateGuidesForBoundingBox:snapRect horizontalGuides:horizontal verticalGuides:vertical];
    
    for (WDDynamicGuide *test in horizontal) {
        WDDynamicGuide *found = [self findCoincidentGuide:test array:horizontalGuides_];
        if (found) {
            [test addExtentsFromSet:found.extents];
            [snapped addObject:test];
        }
    }
    
    for (WDDynamicGuide *test in vertical) {
        WDDynamicGuide *found = [self findCoincidentGuide:test array:verticalGuides_];
        if (found) {
            [test addExtentsFromSet:found.extents];
            [snapped addObject:test];
        }
    }
    
    return snapped;
}

- (CGPoint) offsetSelectionForGuides:(CGPoint)originalDelta inCanvas:(WDCanvas *)canvas
{
    CGRect          selectionBounds = CGRectOffset([canvas.drawingController selectionBounds], originalDelta.x, originalDelta.y);
    double          hDelta, vDelta, currentSmallest = MAXFLOAT;
    double          tolerance = (kDynamicGuideSnappingTolerance / canvas.viewScale);
    
    NSMutableArray *horizontal = [NSMutableArray array];
    NSMutableArray *vertical = [NSMutableArray array];
    
    // generate guides for the offset selection bounds
    [WDDynamicGuide generateGuidesForBoundingBox:selectionBounds horizontalGuides:horizontal verticalGuides:vertical];
    
    // for each test guide, find the nearest real guide and compute a delta
    for (WDDynamicGuide *test in horizontal) {
        hDelta = [self deltaForGuide:test array:horizontalGuides_];
        if (fabs(hDelta) < fabs(currentSmallest)) {
            currentSmallest = hDelta;
        }
    }
    hDelta = fabs(currentSmallest) > tolerance ? 0 : currentSmallest;
    
    currentSmallest = MAXFLOAT;
    for (WDDynamicGuide *test in vertical) {
        vDelta = [self deltaForGuide:test array:verticalGuides_];
        if (fabs(vDelta) < fabs(currentSmallest)) {
            currentSmallest = vDelta;
        }
    }
    vDelta = fabs(currentSmallest) > tolerance ? 0 : currentSmallest;
    
    return WDAddPoints(CGPointMake(hDelta, vDelta), originalDelta);
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

- (void) generateGuides:(WDDrawingController *)drawingController
{
    NSMutableArray *horizontal = [NSMutableArray array];
    NSMutableArray *vertical = [NSMutableArray array];
    
    // add guides for the canvas itself
    [WDDynamicGuide generateGuidesForBoundingBox:drawingController.drawing.bounds horizontalGuides:horizontal verticalGuides:vertical];
    
    // add guides for all unselected drawing elements
    for (WDElement *element in [drawingController unselectedObjects]) {
        [WDDynamicGuide generateGuidesForBoundingBox:element.bounds horizontalGuides:horizontal verticalGuides:vertical];
    }
    
    [horizontalGuides_ removeAllObjects];
    for (WDDynamicGuide *guide in horizontal) {
        [self insertGuide:guide array:horizontalGuides_];
    }
    
    [verticalGuides_ removeAllObjects];
    for (WDDynamicGuide *guide in vertical) {
        [self insertGuide:guide array:verticalGuides_];
    }
    
    generatedGuides_ = YES;
}

@end

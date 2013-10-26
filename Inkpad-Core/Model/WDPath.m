//
//  WDPath.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import "UIColor+Additions.h"
#import "WDArrowhead.h"
#import "WDBezierNode.h"
#import "WDBezierSegment.h"
#import "WDColor.h"
#import "WDCompoundPath.h"
#import "WDFillTransform.h"
#import "WDGLUtilities.h"
#import "WDLayer.h"
#import "WDPath.h"
#import "WDPathfinder.h"
#import "WDShadow.h"
#import "WDUtilities.h"

const float kMiterLimit  = 10;
const float circleFactor = 0.5522847498307936;

NSString *WDReversedPathKey = @"WDReversedPathKey";
NSString *WDSuperpathKey = @"WDSuperpathKey";
NSString *WDNodesKey = @"WDNodesKey";
NSString *WDClosedKey = @"WDClosedKey";

@implementation WDPath

@synthesize closed = closed_;
@synthesize reversed = reversed_;
@synthesize nodes = nodes_;
@synthesize superpath = superpath_;

// to simplify rendering
@synthesize displayNodes = displayNodes_;
@synthesize displayColor = displayColor_;   
@synthesize displayClosed = displayClosed_;

- (id) init
{
    self = [super init];
    
    nodes_ = [[NSMutableArray alloc] init];
    
    if (!self) {
        return nil;
    }
    
    boundsDirty_ = YES;
    
    return self;
}

- (id) initWithNode:(WDBezierNode *)node
{
    self = [super init];
    
    nodes_ = [[NSMutableArray alloc] initWithObjects:node, nil];
    
    if (!self) {
        return nil;
    }

    boundsDirty_ = YES;
    
    return self;
}

- (void) dealloc
{
    if (pathRef_) {
        CGPathRelease(pathRef_);
    }
    
    if (strokePathRef_) {
        CGPathRelease(strokePathRef_);
    }
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeObject:nodes_ forKey:WDNodesKey];
    [coder encodeBool:closed_ forKey:WDClosedKey];
    [coder encodeBool:reversed_ forKey:WDReversedPathKey];
    
    if (superpath_) {
        [coder encodeConditionalObject:superpath_ forKey:WDSuperpathKey];
    }
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    nodes_ = [coder decodeObjectForKey:WDNodesKey];
    closed_ = [coder decodeBoolForKey:WDClosedKey];
    reversed_ = [coder decodeBoolForKey:WDReversedPathKey];
    superpath_ = [coder decodeObjectForKey:WDSuperpathKey];
    
    boundsDirty_ = YES;
    
    return self; 
}

- (NSMutableArray *) reversedNodes
{
    NSMutableArray  *reversed = [NSMutableArray array];
    
    for (WDBezierNode *node in [nodes_ reverseObjectEnumerator]) {
        [reversed addObject:[node flippedNode]];
    }
    
    return reversed;
}

- (void) strokeStyleChanged
{
    [self invalidatePath];
}

- (void) computePathRef
{
    NSArray *nodes = reversed_ ? [self reversedNodes] : nodes_;
    
    // construct the path ref from the node list
    WDBezierNode                *prevNode = nil;
    BOOL                        firstTime = YES;
    
    pathRef_ = CGPathCreateMutable();
    
    for (WDBezierNode *node in nodes) {
        if (firstTime) {
            CGPathMoveToPoint(pathRef_, NULL, node.anchorPoint.x, node.anchorPoint.y);
            firstTime = NO;
        } else if ([prevNode hasOutPoint] || [node hasInPoint]) {
            CGPathAddCurveToPoint(pathRef_, NULL, prevNode.outPoint.x, prevNode.outPoint.y,
                                  node.inPoint.x, node.inPoint.y, node.anchorPoint.x, node.anchorPoint.y);
        } else {
            CGPathAddLineToPoint(pathRef_, NULL, node.anchorPoint.x, node.anchorPoint.y);
        }
        prevNode = node;
    }
    
    if (closed_ && prevNode) {
        WDBezierNode *node = nodes[0];
        CGPathAddCurveToPoint(pathRef_, NULL, prevNode.outPoint.x, prevNode.outPoint.y,
                              node.inPoint.x, node.inPoint.y, node.anchorPoint.x, node.anchorPoint.y);
        
        CGPathCloseSubpath(pathRef_);
    }
}

- (NSArray *) insetForArrowhead:(WDArrowhead *)arrowhead nodes:(NSArray *)nodes attachment:(CGPoint *)attachment angle:(float *)angle
{
    NSMutableArray  *newNodes = [NSMutableArray array];
    NSInteger       numNodes = nodes.count;
    WDBezierNode    *firstNode = nodes[0];
    CGPoint         arrowTip = firstNode.anchorPoint;
    CGPoint         result;
    WDStrokeStyle   *stroke = [self effectiveStrokeStyle];
    float           t, scale = stroke.width;
    BOOL            butt = (stroke.cap == kCGLineCapButt) ? YES : NO;
    
    for (int i = 0; i < numNodes-1; i++) {
        WDBezierNode    *a = nodes[i];
        WDBezierNode    *b = nodes[i+1];
        WDBezierSegment segment = WDBezierSegmentMake(a, b);
        WDBezierSegment L, R;
        
        if (WDBezierSegmentPointDistantFromPoint(segment, [arrowhead insetLength:butt] * scale, arrowTip, &result, &t)) {
            WDBezierSegmentSplitAtT(segment, &L, &R, t);
            [newNodes addObject:[WDBezierNode bezierNodeWithInPoint:result anchorPoint:result outPoint:R.out_]];
            [newNodes addObject:[WDBezierNode bezierNodeWithInPoint:R.in_ anchorPoint:b.anchorPoint outPoint:b.outPoint]];
            
            for (int n = i+2; n < numNodes; n++) {
                [newNodes addObject:nodes[n % numNodes]];
            }
            
            *attachment = result;
            CGPoint delta = WDSubtractPoints(arrowTip, result);
            *angle = atan2(delta.y, delta.x);
            
            break;
        }
    }
    
    return newNodes;
}

- (void) computeStrokePathRef
{
    WDStrokeStyle *stroke = [self effectiveStrokeStyle];
    
    if (strokePathRef_) {
        CGPathRelease(strokePathRef_);
    }
    
    if (![stroke hasArrow]) {
        // since we don't have arrowheads, the stroke path is the same as the fill path
        strokePathRef_ = (CGMutablePathRef) CGPathRetain(self.pathRef);
        return;
    }
    
    // need to calculate arrowhead positions and inset the path appropriately
    
    NSArray *nodes = [nodes_ copy];
    if (closed_) {
        nodes = [nodes arrayByAddingObject:nodes[0]];
    }
    
    // by default, we can fit an arrow
    canFitStartArrow_ = canFitEndArrow_ = YES;
    
    // start arrow?
    WDArrowhead *startArrowhead = [WDArrowhead arrowheads][stroke.startArrow];
    if (startArrowhead) {
        nodes = [self insetForArrowhead:startArrowhead nodes:nodes attachment:&arrowStartAttachment_ angle:&arrowStartAngle_];
        // if we ate up the path, we can't fit
        canFitStartArrow_ = nodes.count;
    }
    
    // end arrow?
    WDArrowhead *endArrowhead = [WDArrowhead arrowheads][stroke.endArrow];
    if (endArrowhead && nodes.count) {
        NSMutableArray *reversed = [NSMutableArray array];
        for (WDBezierNode *node in [nodes reverseObjectEnumerator]) {
            [reversed addObject:[node flippedNode]];
        }
        
        NSArray *result = [self insetForArrowhead:endArrowhead nodes:reversed attachment:&arrowEndAttachment_ angle:&arrowEndAngle_];
        // if we ate up the path, we can't fit
        canFitEndArrow_ = result.count;
        
        if (canFitEndArrow_) {
            nodes = result;
        }
    }
    
    if (!canFitStartArrow_ || !canFitEndArrow_) {
        // we either fit both arrows or no arrows
        canFitStartArrow_ = canFitEndArrow_ = NO;
        strokePathRef_ = (CGMutablePathRef) CGPathRetain(pathRef_);
        return;
    }

    // construct the path ref from the remaining node list
    WDBezierNode    *prevNode = nil;
    BOOL            firstTime = YES;

    strokePathRef_ = CGPathCreateMutable();
    for (WDBezierNode *node in nodes) {
        if (firstTime) {
            CGPathMoveToPoint(strokePathRef_, NULL, node.anchorPoint.x, node.anchorPoint.y);
            firstTime = NO;
        } else if ([prevNode hasOutPoint] || [node hasInPoint]) {
            CGPathAddCurveToPoint(strokePathRef_, NULL, prevNode.outPoint.x, prevNode.outPoint.y,
                                  node.inPoint.x, node.inPoint.y, node.anchorPoint.x, node.anchorPoint.y);
        } else {
            CGPathAddLineToPoint(strokePathRef_, NULL, node.anchorPoint.x, node.anchorPoint.y);
        }
        prevNode = node;
    }
}

- (CGPathRef) strokePathRef
{
    if (nodes_.count == 0) {
        return NULL;
    }
    
    if (!strokePathRef_) {
        [self computeStrokePathRef];
    }
    
    return strokePathRef_;
}

- (CGPathRef) pathRef
{
    if (nodes_.count == 0) {
        return NULL;
    }
    
    if (!pathRef_) {
        [self computePathRef];
    }
    
    return pathRef_;
}

+ (WDPath *) pathWithRect:(CGRect)rect
{
    WDPath *path = [[WDPath alloc] initWithRect:rect];
    return path;
}

+ (WDPath *) pathWithRoundedRect:(CGRect)rect cornerRadius:(float)radius
{
    WDPath *path = [[WDPath alloc] initWithRoundedRect:rect cornerRadius:radius];
    return path;
}

+ (WDPath *) pathWithOvalInRect:(CGRect)rect
{
    WDPath *path = [[WDPath alloc] initWithOvalInRect:rect];
    return path;
}

+ (WDPath *) pathWithStart:(CGPoint)start end:(CGPoint)end
{
    WDPath *path = [[WDPath alloc] initWithStart:start end:end];
    return path;
}

- (id) initWithRect:(CGRect)rect
{
    self = [self init];
    
    if (!self) {
        return nil;
    }
    
    // instantiate nodes for each corner
    
    [nodes_ addObject:[WDBezierNode bezierNodeWithAnchorPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect))]];
    [nodes_ addObject:[WDBezierNode bezierNodeWithAnchorPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect))]];
    [nodes_ addObject:[WDBezierNode bezierNodeWithAnchorPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect))]];
    [nodes_ addObject:[WDBezierNode bezierNodeWithAnchorPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect))]];
    
    self.closed = YES;
    bounds_ = rect;
    
    return self;
}

- (id) initWithRoundedRect:(CGRect)rect cornerRadius:(float)radius
{
    radius = MIN(radius, MIN(CGRectGetHeight(rect) * 0.5f, CGRectGetWidth(rect) * 0.5f));
    
    if (radius <= 0.0f) {
        return [self initWithRect:rect];
    }
    
    self = [self init];
    
    if (!self) {
        return nil;
    }
    
    CGPoint     ul, ur, lr, ll;
    CGPoint     hInset = CGPointMake(radius, 0.0f);
    CGPoint     vInset = CGPointMake(0.0f, radius);
    CGPoint     current;
    CGPoint     xDelta =  CGPointMake(radius * circleFactor, 0);
    CGPoint     yDelta =  CGPointMake(0, radius * circleFactor);
    
    ul = rect.origin;
    ur = CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect));
    lr = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    ll = CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect));
    
    // top edge
    current = WDAddPoints(ul, hInset);
    WDBezierNode *node = [WDBezierNode bezierNodeWithInPoint:WDSubtractPoints(current, xDelta) anchorPoint:current outPoint:current];
    [nodes_ addObject:node];
    
    current = WDSubtractPoints(ur, hInset);
    node = [WDBezierNode bezierNodeWithInPoint:current anchorPoint:current outPoint:WDAddPoints(current, xDelta)];
    [nodes_ addObject:node];
    
    // right edge
    current = WDAddPoints(ur, vInset);
    node = [WDBezierNode bezierNodeWithInPoint:WDSubtractPoints(current, yDelta) anchorPoint:current outPoint:current];
    [nodes_ addObject:node];
    
    current = WDSubtractPoints(lr, vInset);
    node = [WDBezierNode bezierNodeWithInPoint:current anchorPoint:current outPoint:WDAddPoints(current, yDelta)];
    [nodes_ addObject:node];
    
    // bottom edge
    current = WDSubtractPoints(lr, hInset);
    node = [WDBezierNode bezierNodeWithInPoint:WDAddPoints(current, xDelta) anchorPoint:current outPoint:current];
    [nodes_ addObject:node];
    
    current = WDAddPoints(ll, hInset);
    node = [WDBezierNode bezierNodeWithInPoint:current anchorPoint:current outPoint:WDSubtractPoints(current, xDelta)];
    [nodes_ addObject:node];
    
    // left edge
    current = WDSubtractPoints(ll, vInset);
    node = [WDBezierNode bezierNodeWithInPoint:WDAddPoints(current, yDelta) anchorPoint:current outPoint:current];
    [nodes_ addObject:node];
    
    current = WDAddPoints(ul, vInset);
    node = [WDBezierNode bezierNodeWithInPoint:current anchorPoint:current outPoint:WDSubtractPoints(current, yDelta)];
    [nodes_ addObject:node];
    
    self.closed = YES;
    bounds_ = rect;
    
    return self;
}

- (id) initWithOvalInRect:(CGRect)rect
{
    self = [self init];
    
    if (!self) {
        return nil;
    }
    
    // instantiate nodes for each corner
    float minX = CGRectGetMinX(rect);
    float midX = CGRectGetMidX(rect);
    float maxX = CGRectGetMaxX(rect);
    
    float minY = CGRectGetMinY(rect);
    float midY = CGRectGetMidY(rect);
    float maxY = CGRectGetMaxY(rect);
    
    CGPoint xDelta =  CGPointMake((maxX - midX) * circleFactor, 0);
    CGPoint yDelta =  CGPointMake(0, (maxY - midY) * circleFactor);
    
    CGPoint anchor = CGPointMake(minX, midY);
    WDBezierNode *node = [WDBezierNode bezierNodeWithInPoint:WDAddPoints(anchor, yDelta) anchorPoint:anchor outPoint:WDSubtractPoints(anchor, yDelta)];
    [nodes_ addObject:node];
      
    anchor = CGPointMake(midX, minY);
    node = [WDBezierNode bezierNodeWithInPoint:WDSubtractPoints(anchor, xDelta) anchorPoint:anchor outPoint:WDAddPoints(anchor, xDelta)];
    [nodes_ addObject:node];
    
    anchor = CGPointMake(maxX, midY);
    node = [WDBezierNode bezierNodeWithInPoint:WDSubtractPoints(anchor, yDelta) anchorPoint:anchor outPoint:WDAddPoints(anchor, yDelta)];
    [nodes_ addObject:node];
    
    anchor = CGPointMake(midX, maxY);
    node = [WDBezierNode bezierNodeWithInPoint:WDAddPoints(anchor, xDelta) anchorPoint:anchor outPoint:WDSubtractPoints(anchor, xDelta)];
    [nodes_ addObject:node];
    
    self.closed = YES;
    bounds_ = rect;
    
    return self;
}

- (id) initWithStart:(CGPoint)start end:(CGPoint)end
{
    self = [self init];
    
    if (!self) {
        return nil;
    }
    
    [nodes_ addObject:[WDBezierNode bezierNodeWithAnchorPoint:start]];
    [nodes_ addObject:[WDBezierNode bezierNodeWithAnchorPoint:end]];
    
    boundsDirty_ = YES;
    
    return self;
}

- (void) setClosedQuiet:(BOOL)closed
{
    if (closed && nodes_.count < 2) {
        // need at least 2 nodes to close a path
        return;
    }
    
    if (closed) {
        // if the first and last node have the same anchor, one is redundant
        WDBezierNode *first = [self firstNode];
        WDBezierNode *last = [self lastNode];
        if (CGPointEqualToPoint(first.anchorPoint, last.anchorPoint)) {
            WDBezierNode *closedNode = [WDBezierNode bezierNodeWithInPoint:last.inPoint anchorPoint:first.anchorPoint outPoint:first.outPoint];
            
            NSMutableArray *newNodes = [NSMutableArray arrayWithArray:nodes_];
            newNodes[0] = closedNode;
            [newNodes removeLastObject];
            
            self.nodes = newNodes;
        }
    }
    
    closed_ = closed;
}

- (void) setClosed:(BOOL)closed
{
    if (closed && nodes_.count < 2) {
        // need at least 2 nodes to close a path
        return;
    }
    
    [self cacheDirtyBounds];
    [[self.undoManager prepareWithInvocationTarget:self] setClosed:closed_];
    
    [self setClosedQuiet:closed];
    
    [self invalidatePath];
    [self postDirtyBoundsChange];
}

- (BOOL) addNode:(WDBezierNode *)node scale:(float)scale
{
    [self cacheDirtyBounds];
    
    if (nodes_.count && WDDistance(node.anchorPoint, ((WDBezierNode *) nodes_[0]).anchorPoint) < (kNodeSelectionTolerance / scale)) {
        self.closed = YES;
    } else {
        NSMutableArray *newNodes = [nodes_ mutableCopy];
        [newNodes addObject:node];
        self.nodes = newNodes;
    }
    
    [self postDirtyBoundsChange];
    
    return closed_;
}

- (void) addNode:(WDBezierNode *)node
{
    NSMutableArray *newNodes = [NSMutableArray arrayWithArray:nodes_];
    [newNodes addObject:node];
    self.nodes = newNodes;
}

- (void) replaceFirstNodeWithNode:(WDBezierNode *)node
{
    NSMutableArray *newNodes = [NSMutableArray arrayWithArray:nodes_];
    newNodes[0] = node;
    self.nodes = newNodes;
}

- (void) replaceLastNodeWithNode:(WDBezierNode *)node
{
    NSMutableArray *newNodes = [NSMutableArray arrayWithArray:nodes_];
    [newNodes removeLastObject];
    [newNodes addObject:node];
    self.nodes = newNodes;
}

- (WDBezierNode *) firstNode
{
    return nodes_[0];
}

- (WDBezierNode *) lastNode
{
    return (closed_ ? nodes_[0] : [nodes_ lastObject]); 
}

- (void) reversePathDirection
{
    [self cacheDirtyBounds];
    
    [[self.undoManager prepareWithInvocationTarget:self] reversePathDirection];
    
    if (self.strokeStyle && [self.strokeStyle hasArrow]) {
        WDStrokeStyle *flippedArrows = [self.strokeStyle strokeStyleWithSwappedArrows];
        NSSet *changedProperties = [self changedStrokePropertiesFrom:self.strokeStyle to:flippedArrows];
        
        if (changedProperties.count) {
            [self setStrokeStyleQuiet:flippedArrows];
            [self strokeStyleChanged];
            [self propertiesChanged:changedProperties];
        }
    }
    
    reversed_ = !reversed_;
    [self invalidatePath];

    [self postDirtyBoundsChange];
}

- (void) invalidatePath
{
    if (pathRef_) {
        CGPathRelease(pathRef_);
        pathRef_ = NULL;
    }
    
    if (strokePathRef_) {
        CGPathRelease(strokePathRef_);
        strokePathRef_ = NULL;
    }
    
    if (self.superpath) {
        [self.superpath invalidatePath];
    }
    
    boundsDirty_ = YES;
}

// alternative to CGPathGetPathBoundingBox() which didn't exist before iOS 4
- (CGRect) getPathBoundingBox
{
    NSInteger           numNodes = closed_ ? nodes_.count : nodes_.count - 1;
    WDBezierSegment     segment;
    CGRect              bbox = CGRectNull;

    for (int i = 0; i < numNodes; i++) {
        WDBezierNode *a = nodes_[i];
        WDBezierNode *b = nodes_[(i+1) % nodes_.count];
        
        segment.a_ = a.anchorPoint;
        segment.out_ = a.outPoint;
        segment.in_ = b.inPoint;
        segment.b_ = b.anchorPoint;
        
        bbox = CGRectUnion(bbox, WDBezierSegmentBounds(segment));
    }

    return bbox;
}

- (void) computeBounds
{
    bounds_ = CGPathGetPathBoundingBox(self.pathRef);
    boundsDirty_ = NO;
}

/* 
 * Bounding box of path geometry.
 */
- (CGRect) bounds
{
    if (boundsDirty_) {
        [self computeBounds];
    }
    
    return bounds_;
}

- (CGRect) controlBounds
{
    WDBezierNode     *initial = [nodes_ lastObject];
    float           minX, maxX, minY, maxY;
    
    minX = maxX = initial.anchorPoint.x;
    minY = maxY = initial.anchorPoint.y;
    
    for (WDBezierNode *node in nodes_) {
        minX = MIN(minX, node.anchorPoint.x);
        maxX = MAX(maxX, node.anchorPoint.x);
        minY = MIN(minY, node.anchorPoint.y);
        maxY = MAX(maxY, node.anchorPoint.y);
        
        minX = MIN(minX, node.inPoint.x);
        maxX = MAX(maxX, node.inPoint.x);
        minY = MIN(minY, node.inPoint.y);
        maxY = MAX(maxY, node.inPoint.y);
        
        minX = MIN(minX, node.outPoint.x);
        maxX = MAX(maxX, node.outPoint.x);
        minY = MIN(minY, node.outPoint.y);
        maxY = MAX(maxY, node.outPoint.y);
    }
      
    CGRect bbox = CGRectMake(minX, minY, maxX - minX, maxY - minY);
    
    if (self.fillTransform) {
        bbox = WDGrowRectToPoint(bbox, self.fillTransform.transformedStart);
        bbox = WDGrowRectToPoint(bbox, self.fillTransform.transformedEnd);
    }
    
    return bbox;
}

- (CGRect) subselectionBounds
{
    if (![self anyNodesSelected]) {
        return [self bounds];
    }
    
    NSArray *selected = [self selectedNodes];
    WDBezierNode *initial = [selected lastObject];
    float   minX, maxX, minY, maxY;
    
    minX = maxX = initial.anchorPoint.x;
    minY = maxY = initial.anchorPoint.y;
    
    for (WDBezierNode *node in selected) {
        minX = MIN(minX, node.anchorPoint.x);
        maxX = MAX(maxX, node.anchorPoint.x);
        minY = MIN(minY, node.anchorPoint.y);
        maxY = MAX(maxY, node.anchorPoint.y);
    }
    
    return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}

- (WDShadow *) shadowForStyleBounds
{
    return self.superpath ? self.superpath.shadow : self.shadow;;
}

/* 
 * Bounding box of path with its style applied.
 */
- (CGRect) styleBounds
{
    WDStrokeStyle *strokeStyle = [self effectiveStrokeStyle];
    
    if (![strokeStyle willRender]) {
        return [self expandStyleBounds:self.bounds];
    }
        
    float halfWidth =  strokeStyle.width / 2.0f;
    float outset = sqrt((halfWidth * halfWidth) * 2);
        
    // expand by half the stroke width to find the basic bounding box
    CGRect styleBounds = CGRectInset(self.bounds, -outset, -outset);
    
    // include miter joins on corners
    if (nodes_.count > 2 && strokeStyle.join == kCGLineJoinMiter) {
        NSInteger       nodeCount = closed_ ? nodes_.count + 1 : nodes_.count;
        WDBezierNode    *prev = nodes_[0];
        WDBezierNode    *curr = nodes_[1];
        WDBezierNode    *next;
        CGPoint         inPoint, outPoint, inVec, outVec;
        float           miterLength, angle;
        
        for (int i = 1; i < nodeCount; i++) {
            next = nodes_[(i+1) % nodes_.count];
            
            inPoint = [curr hasInPoint] ? curr.inPoint : prev.outPoint;
            outPoint = [curr hasOutPoint] ? curr.outPoint : next.inPoint;
            
            inVec = WDSubtractPoints(inPoint, curr.anchorPoint);
            outVec = WDSubtractPoints(outPoint, curr.anchorPoint);
            
            inVec = WDNormalizePoint(inVec);
            outVec = WDNormalizePoint(outVec);
            
            angle = acos(inVec.x * outVec.x + inVec.y * outVec.y);
            miterLength = strokeStyle.width / sin(angle / 2.0f);
            
            if ((miterLength / strokeStyle.width) < kMiterLimit) {
                CGPoint avg = WDAveragePoints(inVec, outVec);
                CGPoint directed = WDMultiplyPointScalar(WDNormalizePoint(avg), -miterLength / 2.0f);
                
                styleBounds = WDGrowRectToPoint(styleBounds, WDAddPoints(curr.anchorPoint, directed));
            }
            
            prev = curr;
            curr = next;
        }
    }
    
    // add in arrowheads, if any
    if ([strokeStyle hasArrow] && self.nodes && self.nodes.count) {
        float               scale = strokeStyle.width;
        CGRect              arrowBounds;
        WDArrowhead         *arrow;
        
        // make sure this computed
        [self strokePathRef];
        
        // start arrow
        if ([strokeStyle hasStartArrow]) {
            arrow = [WDArrowhead arrowheads][strokeStyle.startArrow];
            arrowBounds = [arrow boundingBoxAtPosition:arrowStartAttachment_ scale:scale angle:arrowStartAngle_
                                     useAdjustment:(strokeStyle.cap == kCGLineCapButt)];
            styleBounds = CGRectUnion(styleBounds, arrowBounds);
        }
        
        // end arrow
        if ([strokeStyle hasEndArrow]) {
            arrow = [WDArrowhead arrowheads][strokeStyle.endArrow];
            arrowBounds = [arrow boundingBoxAtPosition:arrowEndAttachment_ scale:scale angle:arrowEndAngle_
                                     useAdjustment:(strokeStyle.cap == kCGLineCapButt)];
            styleBounds = CGRectUnion(styleBounds, arrowBounds);
        }
    }
    
    return [self expandStyleBounds:styleBounds];
}

- (BOOL) intersectsRect:(CGRect)rect
{
    WDBezierNode 		*prev = nil;
    WDBezierSegment 	seg;
    
    if (nodes_.count == 1) {
        return CGRectContainsPoint(rect, [self firstNode].anchorPoint);
    }
    
    if (!CGRectIntersectsRect(self.bounds, rect)) {
        return NO;
    }
    
    for (WDBezierNode *node in nodes_) {
        if (!prev) {
            prev = node;
            continue;
        }
        
        seg = WDBezierSegmentMake(prev, node);
        if (WDBezierSegmentIntersectsRect(seg, rect)) {
            return YES;
        }
        
        prev = node;
    }
    
    if (self.closed) {
        seg = WDBezierSegmentMake([nodes_ lastObject], nodes_[0]);
        if (WDBezierSegmentIntersectsRect(seg, rect)) {
            return YES;
        }
    }
    
    return NO;
}

- (NSSet *) nodesInRect:(CGRect)rect
{
    NSMutableSet *nodesInRect = [NSMutableSet set];
    
    for (WDBezierNode *node in nodes_) {
        if (CGRectContainsPoint(rect, node.anchorPoint)) {
            [nodesInRect addObject:node];
        }
    }
    
    return nodesInRect;
}

/**************************************************************************
 *
 * Optimized version of -drawOpenGLHighlightWithTransform:viewTransform:
 *
 **************************************************************************/

- (void) drawOpenGLZoomOutlineWithViewTransform:(CGAffineTransform)viewTransform visibleRect:(CGRect)visibleRect
{
    if (!CGRectIntersectsRect(self.bounds, visibleRect)) {
        return;
    }    
    
    if (!nodes_ || nodes_.count == 0) {
        return;
    }
    
    NSArray             *nodes = nodes_;
    NSInteger           numNodes = closed_ ? nodes.count : nodes.count - 1;
    CGPoint             prevIn, prevAnchor, prevOut;
    CGPoint             currIn, currAnchor, currOut;
    WDBezierSegment     segment;
    
    static GLfloat      *vertices = NULL;
    static NSUInteger   size = 128;
    NSUInteger          index = 0;
    
    if (!vertices) {
        vertices = calloc(sizeof(GLfloat), size);
    }
    
    // pre-condition
    WDBezierNode *prev = nodes[0];
    [prev getInPoint:&prevIn anchorPoint:&prevAnchor outPoint:&prevOut selected:NULL];
    
    segment.a_.x = viewTransform.a * prevAnchor.x + viewTransform.c * prevAnchor.y + viewTransform.tx;
    segment.a_.y = viewTransform.b * prevAnchor.x + viewTransform.d * prevAnchor.y + viewTransform.ty;
    
    for (int i = 1; i <= numNodes; i++) {
        WDBezierNode *curr = nodes[i % nodes.count];
        [curr getInPoint:&currIn anchorPoint:&currAnchor outPoint:&currOut selected:NULL];
        
        segment.out_.x = viewTransform.a * prevOut.x + viewTransform.c * prevOut.y + viewTransform.tx;
        segment.out_.y = viewTransform.b * prevOut.x + viewTransform.d * prevOut.y + viewTransform.ty;
        
        segment.in_.x = viewTransform.a * currIn.x + viewTransform.c * currIn.y + viewTransform.tx;
        segment.in_.y = viewTransform.b * currIn.x + viewTransform.d * currIn.y + viewTransform.ty;
        
        segment.b_.x = viewTransform.a * currAnchor.x + viewTransform.c * currAnchor.y + viewTransform.tx;
        segment.b_.y = viewTransform.b * currAnchor.x + viewTransform.d * currAnchor.y + viewTransform.ty;
        
        WDGLFlattenBezierSegment(segment, &vertices, &size, &index);
        
        // set up for the next iteration
        prevOut = currOut;
        segment.a_ = segment.b_;
    }
    
    // assumes proper color set by caller
    WDGLDrawLineStrip(vertices, index);
}

- (void) drawOpenGLHighlightWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{    
    NSArray             *nodes = displayNodes_ ? displayNodes_ : nodes_;
    
    if (!nodes || nodes.count == 0) {
        return;
    }
    
    BOOL                transformAll = ![self anyNodesSelected];
    BOOL                closed = displayNodes_ ? displayClosed_ : closed_;
    NSInteger           numNodes = closed ? nodes.count : nodes.count - 1;
    CGAffineTransform   combined = CGAffineTransformConcat(transform, viewTransform);
    CGPoint             prevIn, prevAnchor, prevOut;
    CGPoint             currIn, currAnchor, currOut;
    BOOL                prevSelected, currSelected;
    CGAffineTransform   prevTx, currTx;
    WDBezierSegment     segment;
    
    static GLfloat      *vertices = NULL;
    static NSUInteger   size = 128;
    NSUInteger          index = 0;
    
    if (!vertices) {
        vertices = calloc(sizeof(GLfloat), size);
    }
    
    // pre-condition
    WDBezierNode *prev = nodes[0];
    [prev getInPoint:&prevIn anchorPoint:&prevAnchor outPoint:&prevOut selected:&prevSelected];
    
    prevTx = (prevSelected || transformAll) ? combined : viewTransform;
    
    // segment.a_ = CGPointApplyAffineTransform(prevAnchor, (prevSelected || transformAll) ? combined : viewTransform);
    segment.a_.x = prevTx.a * prevAnchor.x + prevTx.c * prevAnchor.y + prevTx.tx;
    segment.a_.y = prevTx.b * prevAnchor.x + prevTx.d * prevAnchor.y + prevTx.ty;
    
    for (int i = 1; i <= numNodes; i++) {
        WDBezierNode *curr = nodes[i % nodes.count];
        [curr getInPoint:&currIn anchorPoint:&currAnchor outPoint:&currOut selected:&currSelected];
        
        // segment.out_ = CGPointApplyAffineTransform(prevOut, (prevSelected || transformAll) ? combined : viewTransform);
        segment.out_.x = prevTx.a * prevOut.x + prevTx.c * prevOut.y + prevTx.tx;
        segment.out_.y = prevTx.b * prevOut.x + prevTx.d * prevOut.y + prevTx.ty;
        
        currTx = (currSelected || transformAll) ? combined : viewTransform;
        
        // segment.in_ = CGPointApplyAffineTransform(currIn, (currSelected || transformAll) ? combined : viewTransform);
        segment.in_.x = currTx.a * currIn.x + currTx.c * currIn.y + currTx.tx;
        segment.in_.y = currTx.b * currIn.x + currTx.d * currIn.y + currTx.ty;
        
        //segment.b_ = CGPointApplyAffineTransform(currAnchor, (currSelected || transformAll) ? combined : viewTransform);
        segment.b_.x = currTx.a * currAnchor.x + currTx.c * currAnchor.y + currTx.tx;
        segment.b_.y = currTx.b * currAnchor.x + currTx.d * currAnchor.y + currTx.ty;

        WDGLFlattenBezierSegment(segment, &vertices, &size, &index);
        
        // set up for the next iteration
        prevSelected = currSelected;
        prevOut = currOut;
        prevTx = currTx;
        segment.a_ = segment.b_;
    }
    
    displayColor_ ? [displayColor_ openGLSet]: [self.layer.highlightColor openGLSet];
    WDGLDrawLineStrip(vertices, index);
}

- (void) drawOpenGLAnchorsWithViewTransform:(CGAffineTransform)transform
{
    UIColor *color = displayColor_ ? displayColor_ : self.layer.highlightColor;
    NSArray *nodes = displayNodes_ ? displayNodes_ : nodes_;
    
    for (WDBezierNode *node in nodes) {
        [node drawGLWithViewTransform:transform color:color mode:kWDBezierNodeRenderClosed];
    }
}

- (void) drawOpenGLHandlesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    CGAffineTransform   combined = CGAffineTransformConcat(transform, viewTransform);
    UIColor             *color = displayColor_ ? displayColor_ : self.layer.highlightColor;
    NSArray             *nodes = displayNodes_ ? displayNodes_ : nodes_;
    
    for (WDBezierNode *node in nodes) {
        if (node.selected) {
            [node drawGLWithViewTransform:combined color:color mode:kWDBezierNodeRenderSelected];
        } else {
            [node drawGLWithViewTransform:viewTransform color:color mode:kWDBezierNodeRenderOpen];
        }
    }
}

- (BOOL) anyNodesSelected
{
    for (WDBezierNode *node in nodes_) {
        if (node.selected) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL) allNodesSelected
{
    for (WDBezierNode *node in nodes_) {
        if (!node.selected) {
            return NO;
        }
    }
    
    return YES;
}

- (NSSet *) alignToRect:(CGRect)rect alignment:(WDAlignment)align
{
    if (![self anyNodesSelected]) {
        return [super alignToRect:rect alignment:align];
    }
    
    CGPoint             topLeft = rect.origin;
    CGPoint             rectCenter = WDCenterOfRect(rect);
    CGPoint             bottomRight = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    CGAffineTransform   translate = CGAffineTransformIdentity;
    NSMutableArray      *newNodes = [NSMutableArray array];
    NSMutableSet        *exchangedNodes = [NSMutableSet set];
    
    for (WDBezierNode *node in nodes_) {
        if (node.selected) {
            switch(align) {
                case WDAlignLeft:
                    translate = CGAffineTransformMakeTranslation(topLeft.x - node.anchorPoint.x, 0.0f);
                    break;
                case WDAlignCenter:
                    translate = CGAffineTransformMakeTranslation(rectCenter.x - node.anchorPoint.x, 0.0f);
                    break;
                case WDAlignRight:
                    translate = CGAffineTransformMakeTranslation(bottomRight.x - node.anchorPoint.x, 0.0f);
                    break;
                case WDAlignTop:
                    translate = CGAffineTransformMakeTranslation(0.0f, topLeft.y - node.anchorPoint.y);  
                    break;
                case WDAlignMiddle:
                    translate = CGAffineTransformMakeTranslation(0.0f, rectCenter.y - node.anchorPoint.y);
                    break;
                case WDAlignBottom:          
                    translate = CGAffineTransformMakeTranslation(0.0f, bottomRight.y - node.anchorPoint.y);
                    break;
            }
            
            WDBezierNode *alignedNode = [node transform:translate];
            [newNodes addObject:alignedNode];
            [exchangedNodes addObject:alignedNode];
        } else {
            [newNodes addObject:node];
        }
    }

    self.nodes = newNodes;
    
    return exchangedNodes;
}

- (void) setNodes:(NSMutableArray *)nodes
{
    if ([nodes_ isEqualToArray:nodes]) {
        return;
    }
    
    [self cacheDirtyBounds];
    
    [[self.undoManager prepareWithInvocationTarget:self] setNodes:nodes_];
    
    nodes_ = nodes;
    
    [self invalidatePath];
    
    [self postDirtyBoundsChange];
}

- (NSSet *) transform:(CGAffineTransform)transform
{
    NSMutableArray      *newNodes = [[NSMutableArray alloc] init];
    BOOL                transformAll = [self anyNodesSelected] ? NO : YES;
    NSMutableSet        *exchangedNodes = [NSMutableSet set];
    
    for (WDBezierNode *node in nodes_) {
        if (transformAll || node.selected) {
            WDBezierNode *transformed = [node transform:transform];
            [newNodes addObject:transformed];
            
            if (node.selected) {
                [exchangedNodes addObject:transformed];
            }
        } else {
            [newNodes addObject:node];
        }
    }
    
    self.nodes = newNodes;
    
    if (transformAll) {
        // parent transforms masked elements and fill transform
        [super transform:transform];
    }
    
    return exchangedNodes;
}

- (NSArray *) selectedNodes
{   
    NSMutableArray *selected = [NSMutableArray array];
    
    for (WDBezierNode *node in nodes_) {
        if (node.selected) {
            [selected addObject:node];
        }
    }
    
    return selected;
}

// When splitting a path there are two cases. Spliting a closed path (reopen it)
// and splitting an open path (breaking it into two)
- (NSDictionary *) splitAtNode:(WDBezierNode *)node
{
    NSMutableDictionary *whatToSelect = [NSMutableDictionary dictionary];
    NSUInteger          i, startIx = [nodes_ indexOfObject:node];
    
    if (self.closed) {
        NSMutableArray  *newNodes = [NSMutableArray array];
        
        for (i = startIx; i < nodes_.count; i++) {
            [newNodes addObject:nodes_[i]];
        }
        
        for (i = 0; i < startIx; i++) {
            [newNodes addObject:nodes_[i]];
        }
        
        [newNodes addObject:[node copy]]; // copy this node since it would otherwise be shared
        
        self.nodes = newNodes;
        self.closed = NO; // can't be closed now
        
        whatToSelect[@"path"] = self;
        whatToSelect[@"node"] = [newNodes lastObject];
    } else {
        // the original path gets the first half of the original nodes
        NSMutableArray  *newNodes = [NSMutableArray array];
        for (i = 0; i < startIx; i++) {
            [newNodes addObject:nodes_[i]];
        }
        [newNodes addObject:[node copy]]; // copy this node since it would otherwise be shared
        
        // create a new path to take the rest of the nodes
        WDPath *sibling = [[WDPath alloc] init];
        NSMutableArray  *siblingNodes = [NSMutableArray array];
        for (i = startIx; i < nodes_.count; i++) {
            [siblingNodes addObject:nodes_[i]];
        }
        
        // set this after building siblingNodes so that nodes_ doesn't go away
        self.nodes = newNodes;
        
        sibling.nodes = siblingNodes;
        sibling.fill = self.fill;
        sibling.fillTransform = self.fillTransform;
        sibling.strokeStyle = self.strokeStyle;
        sibling.opacity = self.opacity;
        sibling.shadow = self.shadow;
        
        if (self.reversed) {
            [sibling reversePathDirection];
        }
        
        if (self.superpath) {
            [self.superpath addSubpath:sibling];
        } else {
            [self.layer insertObject:sibling above:self];
        }
        
        whatToSelect[@"path"] = sibling;
        whatToSelect[@"node"] = siblingNodes[0];
    }
    
    return whatToSelect;
}

- (NSDictionary *) splitAtPoint:(CGPoint)pt viewScale:(float)viewScale
{
    WDBezierNode *node = [self addAnchorAtPoint:pt viewScale:viewScale];
    
    return [self splitAtNode:node];
}

- (WDBezierNode *) addAnchorAtPoint:(CGPoint)pt viewScale:(float)viewScale
{
    NSMutableArray      *newNodes = [NSMutableArray array];
    NSInteger           numNodes = closed_ ? (nodes_.count + 1) : nodes_.count;
    NSInteger           numSegments = numNodes; // includes an extra one for the one that gets split
    WDBezierSegment     segments[numSegments];
    WDBezierSegment     segment;
    WDBezierNode        *prev, *curr, *node, *newestNode = nil;
    NSUInteger          newestNodeSegmentIx = 0, segmentIndex = 0;
    float               t;
    BOOL                added = NO;

    prev = nodes_[0];
    for (int i = 1; i < numNodes; i++, segmentIndex ++) {
        curr = nodes_[(i % nodes_.count)];
        
        segment = WDBezierSegmentMake(prev, curr);
        
        if (!added && WDBezierSegmentFindPointOnSegment(segment, pt, kNodeSelectionTolerance / viewScale, NULL, &t)) {
            WDBezierSegmentSplitAtT(segment,  &segments[segmentIndex], &segments[segmentIndex+1], t);
            segmentIndex++;
            newestNodeSegmentIx = segmentIndex;
            added = YES;
        } else {
            segments[segmentIndex] = segment;
        }
        
        prev = curr;
    }

    // convert the segments back to nodes
    for (int i = 0; i < numSegments; i++) {
        if (i == 0) {
            CGPoint inPoint = closed_ ? segments[numSegments - 1].in_ : [self firstNode].inPoint;
            node = [WDBezierNode bezierNodeWithInPoint:inPoint anchorPoint:segments[i].a_ outPoint:segments[i].out_];
        } else {
            node = [WDBezierNode bezierNodeWithInPoint:segments[i-1].in_ anchorPoint:segments[i].a_ outPoint:segments[i].out_];
        }
        
        [newNodes addObject:node];
        
        if (i == newestNodeSegmentIx) {
            newestNode = node;
        }
        
        if (i == (numSegments - 1) && !closed_) {
            node = [WDBezierNode bezierNodeWithInPoint:segments[i].in_ anchorPoint:segments[i].b_ outPoint:[self lastNode].outPoint];
            [newNodes addObject:node];
        }
    }

    self.nodes = newNodes;

    return newestNode;
}

- (void) addAnchors
{
    NSMutableArray      *newNodes = [NSMutableArray array];
    NSInteger           numNodes = closed_ ? (nodes_.count + 1) : nodes_.count;
    NSInteger           numSegments = (numNodes - 1) * 2;
    WDBezierSegment     segments[numSegments];
    WDBezierSegment     segment;
    WDBezierNode        *prev, *curr, *node;
    NSUInteger          segmentIndex = 0;
    
    prev = nodes_[0];
    for (int i = 1; i < numNodes; i++, segmentIndex += 2) {
        curr = nodes_[(i % nodes_.count)];
        
        segment = WDBezierSegmentMake(prev, curr);
        WDBezierSegmentSplit(segment, &segments[segmentIndex], &segments[segmentIndex+1]);
        
        prev = curr;
    }
    
    // convert the segments back to nodes
    for (int i = 0; i < numSegments; i++) {
        if (i == 0) {
            CGPoint inPoint = closed_ ? segments[numSegments - 1].in_ : [self firstNode].inPoint;
            node = [WDBezierNode bezierNodeWithInPoint:inPoint anchorPoint:segments[i].a_ outPoint:segments[i].out_];
        } else {
            node = [WDBezierNode bezierNodeWithInPoint:segments[i-1].in_ anchorPoint:segments[i].a_ outPoint:segments[i].out_];
        }
        
        [newNodes addObject:node];
        
        if (i == (numSegments - 1) && !closed_) {
            node = [WDBezierNode bezierNodeWithInPoint:segments[i].in_ anchorPoint:segments[i].b_ outPoint:[self lastNode].outPoint];
            [newNodes addObject:node];
        }
    }
    
    self.nodes = newNodes;
}

- (BOOL) canDeleteAnchors
{
    NSUInteger unselectedCount = 0;
    NSUInteger selectedCount = 0;
    
    for (WDBezierNode *node in nodes_) {
        if (!node.selected) {
            unselectedCount++;
        } else {
            selectedCount++;
        }
        
        if (unselectedCount >= 2 && selectedCount > 0) {
            return YES;
        }
    }
    
    return NO;
}

- (void) deleteAnchor:(WDBezierNode *)node
{
    if (nodes_.count > 2) {
        NSMutableArray *newNodes = [nodes_ mutableCopy];
        [newNodes removeObject:node];
        self.nodes = newNodes;
    }
}

- (void) deleteAnchors
{   
    NSMutableArray *newNodes = [nodes_ mutableCopy];
    [newNodes removeObjectsInArray:[self selectedNodes]];
    self.nodes = newNodes;
}

- (void) appendPath:(WDPath *)path
{
    NSArray     *baseNodes, *nodesToAdd;
    CGPoint     delta;
    BOOL        reverseMyNodes = YES;
    BOOL        reverseIncomingNodes = NO;
    float       distance, minDistance = WDDistance([self firstNode].anchorPoint, [path firstNode].anchorPoint);
    
    // find the closest pair of end points
    distance = WDDistance([self firstNode].anchorPoint, [path lastNode].anchorPoint);
    if (distance < minDistance) {
        minDistance = distance;
        reverseIncomingNodes = YES;
    }
    
    distance = WDDistance([path firstNode].anchorPoint, [self lastNode].anchorPoint);
    if (distance < minDistance) {
        minDistance = distance;
        reverseMyNodes = NO;
        reverseIncomingNodes = NO;
    }
    
    distance = WDDistance([path lastNode].anchorPoint, [self lastNode].anchorPoint);
    if (distance < minDistance) {
        reverseMyNodes = NO;
        reverseIncomingNodes = YES;
    }
    
    baseNodes = reverseMyNodes ? self.reversedNodes : self.nodes;
    nodesToAdd = reverseIncomingNodes ? path.reversedNodes : path.nodes;
    
    // add the base nodes (up to the shared node) to the new nodes
    NSMutableArray *newNodes = [NSMutableArray array];
    for (int i = 0; i < baseNodes.count - 1; i++) {
        [newNodes addObject:baseNodes[i]];
    }
    
    // compute the translation necessary to align the incoming path
    WDBezierNode *lastNode = [baseNodes lastObject];
    WDBezierNode *firstNode = nodesToAdd[0];
    delta = WDSubtractPoints(lastNode.anchorPoint, firstNode.anchorPoint);
    CGAffineTransform transform = CGAffineTransformMakeTranslation(delta.x, delta.y);
    
    // add the shared node (combine the handles appropriately)
    firstNode = [firstNode transform:transform];
    [newNodes addObject:[WDBezierNode bezierNodeWithInPoint:lastNode.inPoint anchorPoint:firstNode.anchorPoint outPoint:firstNode.outPoint]];
    
    // add the incoming path's nodes
    for (int i = 1; i < nodesToAdd.count; i++) {
        [newNodes addObject:[nodesToAdd[i] transform:transform]];
    }
    
    // see if the last node is the same as the first node
    firstNode = newNodes[0];
    lastNode = [newNodes lastObject];
    
    if (WDDistance(firstNode.anchorPoint, lastNode.anchorPoint) < 0.5f) {
        WDBezierNode *closedNode = [WDBezierNode bezierNodeWithInPoint:lastNode.inPoint anchorPoint:firstNode.anchorPoint outPoint:firstNode.outPoint];
        newNodes[0] = closedNode;
        [newNodes removeLastObject];
        self.closed = YES;
    }
    
    self.nodes = newNodes;
}

- (WDBezierNode *) convertNode:(WDBezierNode *)node whichPoint:(WDPickResultType)whichPoint
{
    WDBezierNode     *newNode = nil;
    
    if (whichPoint == kWDInPoint) {
        newNode = [node chopInHandle];
    } else if (whichPoint == kWDOutPoint) {
        newNode = [node chopOutHandle];
    } else {
        if (node.hasInPoint || node.hasOutPoint) {
            newNode = [node chopHandles];
        } else {
            NSInteger ix = [nodes_ indexOfObject:node];
            NSInteger pix, nix;
            WDBezierNode *prev = nil, *next = nil;
            
            pix = ix - 1;
            if (pix >= 0) {
                prev = nodes_[pix];
            } else if (closed_ && nodes_.count > 2) {
                prev = [nodes_ lastObject];
            }
            
            nix = ix + 1;
            if (nix < nodes_.count) {
                next = nodes_[nix];
            } else if (closed_ && nodes_.count > 2) {
                next = nodes_[0];
            }
            
            if (!prev) {
                prev = node;
            }
            
            if (!next) {
                next = node;
            }
            
            if (prev && next) {
                CGPoint    vector = WDSubtractPoints(next.anchorPoint, prev.anchorPoint);
                float      magnitude = WDDistance(vector, CGPointZero);
                
                vector = WDNormalizePoint(vector);
                vector = WDMultiplyPointScalar(vector, magnitude / 4.0f);
                
                newNode = [WDBezierNode bezierNodeWithInPoint:WDSubtractPoints(node.anchorPoint, vector) anchorPoint:node.anchorPoint outPoint:WDAddPoints(node.anchorPoint, vector)];
            }
        }
    }
    
    NSMutableArray *newNodes = [NSMutableArray array];
    for (WDBezierNode *oldNode in nodes_) {
        if (node == oldNode) {
            [newNodes addObject:newNode];
        } else {
            [newNodes addObject:oldNode];
        }
    }
    
    self.nodes = newNodes;
    
    return newNode;
}

- (BOOL) hasFill
{
    return [super hasFill] || self.maskedElements;
}

- (WDPickResult *) hitResultForPoint:(CGPoint)point viewScale:(float)viewScale snapFlags:(int)flags
{
    WDPickResult        *result = [WDPickResult pickResult];
    CGRect              pointRect = WDRectFromPoint(point, kNodeSelectionTolerance / viewScale, kNodeSelectionTolerance / viewScale);
    float               distance, minDistance = MAXFLOAT;
    float               tolerance = kNodeSelectionTolerance / viewScale;
    
    if (!CGRectIntersectsRect(pointRect, [self controlBounds])) {
        return result;
    }
    
    if (flags & kWDSnapNodes) {
        // look for fill control points
        if (self.fillTransform) {
            distance = WDDistance([self.fillTransform transformedStart], point);
            if (distance < MIN(tolerance, minDistance)) {
                result.type = kWDFillStartPoint;
                minDistance = distance;
            }
            
            distance = WDDistance([self.fillTransform transformedEnd], point);
            if (distance < MIN(tolerance, minDistance)) {
                result.type = kWDFillEndPoint;
                minDistance = distance;
            }
        }
        
        // pre-existing selected node gets first crack
        for (WDBezierNode *selectedNode in [self selectedNodes]) {
            distance = WDDistance(selectedNode.anchorPoint, point);
            if (distance < MIN(tolerance, minDistance)) {
                result.node = selectedNode;
                result.type = kWDAnchorPoint;
                minDistance = distance;
            }
            
            distance = WDDistance(selectedNode.outPoint, point);
            if (distance < MIN(tolerance, minDistance)) {
                result.node = selectedNode;
                result.type = kWDOutPoint;
                minDistance = distance;
            }
            
            distance = WDDistance(selectedNode.inPoint, point);
            if (distance < MIN(tolerance, minDistance)) {
                result.node = selectedNode;
                result.type = kWDInPoint;
                minDistance = distance;
            } 
        }
        
        for (WDBezierNode *node in nodes_) {
            distance = WDDistance(node.anchorPoint, point);
            if (distance < MIN(tolerance, minDistance)) {
                result.node = node;
                result.type = kWDAnchorPoint;
                minDistance = distance;
            }
        }
        
        if (result.type != kWDEther) {
            result.element = self;
            return result;
        }
    }
    
    if (flags & kWDSnapEdges) {
        // check path edges
        NSInteger           numNodes = closed_ ? nodes_.count : nodes_.count - 1;
        WDBezierSegment     segment;
        
        for (int i = 0; i < numNodes; i++) {
            WDBezierNode    *a = nodes_[i];
            WDBezierNode    *b = nodes_[(i+1) % nodes_.count];
            CGPoint         nearest;
            
            segment.a_ = a.anchorPoint;
            segment.out_ = a.outPoint;
            segment.in_ = b.inPoint;
            segment.b_ = b.anchorPoint;
            
            if (WDBezierSegmentFindPointOnSegment(segment, point, kNodeSelectionTolerance / viewScale, &nearest, NULL)) {
                result.element = self;
                result.type = kWDEdge;
                result.snappedPoint = nearest;
                
                return result;
            }
        }
    }
    
    if ((flags & kWDSnapFills) && ([self hasFill])) {
        if (CGPathContainsPoint(self.pathRef, NULL, point, self.fillRule)) {
            result.element = self;
            result.type = kWDObjectFill;
            return result;
        }
    }
    
    return result;
}

- (WDPickResult *) snappedPoint:(CGPoint)point viewScale:(float)viewScale snapFlags:(int)flags
{
    WDPickResult        *result = [WDPickResult pickResult];
    CGRect              pointRect = WDRectFromPoint(point, kNodeSelectionTolerance / viewScale, kNodeSelectionTolerance / viewScale);
    
    if (!CGRectIntersectsRect(pointRect, [self controlBounds])) {
        return result;
    }
    
    if (flags & kWDSnapNodes) {
        for (WDBezierNode *node in nodes_) {
            if (WDDistance(node.anchorPoint, point) < (kNodeSelectionTolerance / viewScale)) {
                result.element = self;
                result.node = node;
                result.type = kWDAnchorPoint;
                result.nodePosition = kWDMiddleNode;
                result.snappedPoint = node.anchorPoint;
                
                if (!closed_) {
                    if (node == nodes_[0]) {
                        result.nodePosition = kWDFirstNode;
                    } else if (node == [nodes_ lastObject]) {
                        result.nodePosition = kWDLastNode;
                    }
                }
                
                return result;
            }
        }
    }
    
    if (flags & kWDSnapEdges) {
        // check path edges
        NSInteger           numNodes = closed_ ? nodes_.count : nodes_.count - 1;
        WDBezierSegment     segment;
        
        
        for (int i = 0; i < numNodes; i++) {
            WDBezierNode    *a = nodes_[i];
            WDBezierNode    *b = nodes_[(i+1) % nodes_.count];
            CGPoint         nearest;
            
            segment.a_ = a.anchorPoint;
            segment.out_ = a.outPoint;
            segment.in_ = b.inPoint;
            segment.b_ = b.anchorPoint;
            
            if (WDBezierSegmentFindPointOnSegment(segment, point, kNodeSelectionTolerance / viewScale, &nearest, NULL)) {
                result.element = self;
                result.type = kWDEdge;
                result.snappedPoint = nearest;
                
                return result;
            }
        }
    }
    
    return result;
}

- (void) setSuperpath:(WDCompoundPath *)superpath
{
    [[self.undoManager prepareWithInvocationTarget:self] setSuperpath:superpath_];
    
    superpath_ = superpath;
    
    if (superpath) {
        self.fill = nil;
        self.strokeStyle = nil;
        self.fillTransform = nil;
        self.shadow = nil;
    }
}

- (void) setValue:(id)value forProperty:(NSString *)property propertyManager:(WDPropertyManager *)propertyManager
{
    if (self.superpath) {
        [self.superpath setValue:value forProperty:property propertyManager:propertyManager];
        return;
    }
    
    return [super setValue:value forProperty:property propertyManager:propertyManager];
}

- (id) valueForProperty:(NSString *)property
{
    if (self.superpath) {
        return [self.superpath valueForProperty:property];
    }
    
    return [super valueForProperty:property];
}

- (BOOL) canPlaceText
{
    return (!self.superpath && !self.maskedElements);
}

- (NSArray *) erase:(WDAbstractPath *)erasePath
{
    if (self.closed) {
        WDAbstractPath *result = [WDPathfinder combinePaths:@[self, erasePath] operation:WDPathFinderSubtract];
        
        if (!result) {
            return @[];
        }
        
        [result takeStylePropertiesFrom:self];
        
        if (self.superpath && [result isKindOfClass:[WDCompoundPath class]]) {
            WDCompoundPath *cp = (WDCompoundPath *)result;
            [[cp subpaths] makeObjectsPerformSelector:@selector(setSuperpath:) withObject:nil];
            return cp.subpaths;
        }
        
        return @[result];
    } else {
        if (!CGRectIntersectsRect(self.bounds, erasePath.bounds)) {
            WDPath *clone = [[WDPath alloc] init];
            [clone takeStylePropertiesFrom:self];
            NSMutableArray *nodes = [self.nodes mutableCopy];
            clone.nodes = nodes;
            
            NSArray *result = @[clone];
            return result;
        }
        
        // break down path
        NSArray             *nodes = reversed_ ? [self reversedNodes] : nodes_;
        NSInteger           segmentCount = nodes.count - 1;
        WDBezierSegment     segments[segmentCount]; 
        
        WDBezierSegment     *splitSegments;
        NSUInteger          splitSegmentSize = 256;
        int                 splitSegmentIx = 0;
        
        WDBezierNode        *prev, *curr;
        
        // this might need to grow, so dynamically allocate it
        splitSegments = calloc(sizeof(WDBezierSegment), splitSegmentSize);
        
        prev = nodes[0];
        for (int i = 1; i < nodes.count; i++, prev = curr) {
            curr = nodes[i];
            segments[i-1] = WDBezierSegmentMake(prev, curr);
        }
        
        erasePath = [erasePath pathByFlatteningPath];
        
        WDBezierSegment     L, R;
        NSArray             *subpaths = [erasePath isKindOfClass:[WDPath class]] ? @[erasePath] : [(WDCompoundPath *)erasePath subpaths];
        float               smallestT, t;
        BOOL                intersected;
        
        for (int i = 0; i < segmentCount; i++) {
            smallestT = MAXFLOAT;
            intersected = NO;
            
            // split the segments into more segments at every intersection with the erasing path
            for (WDPath *subpath in subpaths) {
                prev = (subpath.nodes)[0];
                
                for (int n = 1; n < subpath.nodes.count; n++, prev = curr) {
                    curr = (subpath.nodes)[n];
                    
                    if (WDBezierSegmentGetIntersection(segments[i], prev.anchorPoint, curr.anchorPoint, &t)) {
                        if (t < smallestT && (fabs(t) > 0.001)) {
                            smallestT = t;
                            intersected = YES;
                        }
                    }
                }
            }
                
            if (!intersected || fabs(1 - smallestT) < 0.001) {
                splitSegments[splitSegmentIx++] = segments[i];
            } else {
                WDBezierSegmentSplitAtT(segments[i], &L, &R, smallestT);
                                    
                splitSegments[splitSegmentIx++] = L;
                segments[i] = R;
                i--;
            }
            
            if (splitSegmentIx >= splitSegmentSize) {
                splitSegmentSize *= 2;
                splitSegments = realloc(splitSegments, sizeof(WDBezierSegment) * splitSegmentSize);
            }
        }
        
        // toss out any segment that's inside the erase path
        WDBezierSegment newSegments[splitSegmentIx];
        int             newSegmentIx = 0;
        
        for (int i = 0; i < splitSegmentIx; i++) {
            CGPoint midPoint = WDBezierSegmentSplitAtT(splitSegments[i], NULL, NULL, 0.5);
            
            if (![erasePath containsPoint:midPoint]) {
                newSegments[newSegmentIx++] = splitSegments[i];
            }
        }

        // clean up
        free(splitSegments);
                    
        if (newSegmentIx == 0) {
            return @[];
        }
        
        // reassemble segments
        NSMutableArray  *array = [NSMutableArray array];
        WDPath          *currentPath = [[WDPath alloc] init];
        
        [currentPath takeStylePropertiesFrom:self];
        [array addObject:currentPath];
        
        for (int i = 0; i < newSegmentIx; i++) {
            WDBezierNode *lastNode = [currentPath lastNode];
            
            if (!lastNode) {            
                [currentPath addNode:[WDBezierNode bezierNodeWithInPoint:newSegments[i].a_ anchorPoint:newSegments[i].a_ outPoint:newSegments[i].out_]];
            } else if (CGPointEqualToPoint(lastNode.anchorPoint, newSegments[i].a_)) {
                [currentPath replaceLastNodeWithNode:[WDBezierNode bezierNodeWithInPoint:lastNode.inPoint anchorPoint:lastNode.anchorPoint outPoint:newSegments[i].out_]];
            } else {
                currentPath = [[WDPath alloc] init];
                [currentPath takeStylePropertiesFrom:self];
                [array addObject:currentPath];
                
                [currentPath addNode:[WDBezierNode bezierNodeWithInPoint:newSegments[i].a_ anchorPoint:newSegments[i].a_ outPoint:newSegments[i].out_]];
            }
            
            [currentPath addNode:[WDBezierNode bezierNodeWithInPoint:newSegments[i].in_ anchorPoint:newSegments[i].b_ outPoint:newSegments[i].b_]];
        }
        
        return array;
    }
}

- (void) simplify
{
    // strip collinear anchors
    
    if (nodes_.count < 3) {
        return;
    }
    
    NSMutableArray  *newNodes = [NSMutableArray array];
    WDBezierNode    *current, *next, *nextnext;
    NSInteger       nodeCount = closed_ ? nodes_.count + 1 : nodes_.count;
    NSInteger       ix = 0;
    
    current = nodes_[ix++];
    next = nodes_[ix++];
    nextnext = nodes_[ix++];
    
    [newNodes addObject:current];
    
    while (nextnext) {
        if (!WDCollinear(current.anchorPoint, current.outPoint, next.inPoint) ||
            !WDCollinear(current.anchorPoint, next.inPoint, next.anchorPoint) ||
            !WDCollinear(current.anchorPoint, next.anchorPoint, next.outPoint) ||
            !WDCollinear(current.anchorPoint, next.anchorPoint, nextnext.inPoint) ||
            !WDCollinear(current.anchorPoint, next.anchorPoint, nextnext.anchorPoint))
        {
            // can't remove the node, add it and move on
            [newNodes addObject:next];
            current = next;
        }
        
        next = nextnext;
        
        if (ix < nodeCount) {
            nextnext = nodes_[(ix % nodes_.count)];
        } else {
            nextnext = nil;
        }
        
        ix++;
    }
    
    if (!closed_) {
        [newNodes addObject:next];
    }
    
    if (closed_) {
        // see if we should remove the first node
        current = [nodes_ lastObject];
        next = nodes_[0];
        nextnext = nodes_[1];
        
        if (WDCollinear(current.anchorPoint, current.outPoint, next.inPoint) &&
            WDCollinear(current.anchorPoint, next.inPoint, next.anchorPoint) &&
            WDCollinear(current.anchorPoint, next.anchorPoint, next.outPoint) &&
            WDCollinear(current.anchorPoint, next.anchorPoint, nextnext.inPoint) &&
            WDCollinear(current.anchorPoint, next.anchorPoint, nextnext.anchorPoint))
        {
            [newNodes removeObjectAtIndex:0];
        }
    }
    
    self.nodes = newNodes;
}

- (NSMutableArray *) flattenedNodes
{
    NSMutableArray      *flatNodes = [NSMutableArray array];
    NSInteger           numNodes = closed_ ? nodes_.count : nodes_.count - 1;
    WDBezierSegment     segment;
    static CGPoint      *vertices = NULL;
    static NSUInteger   size = 128;
    NSUInteger          index = 0;
    
    if (!vertices) {
        vertices = calloc(sizeof(CGPoint), size);
    }
    
    for (int i = 0; i < numNodes; i++) {
        WDBezierNode *a = nodes_[i];
        WDBezierNode *b = nodes_[(i+1) % nodes_.count];
        
        // reset the index for the current segment
        index = 0;
        
        segment.a_ = a.anchorPoint;
        segment.out_ = a.outPoint;
        segment.in_ = b.inPoint;
        segment.b_ = b.anchorPoint;
        
        WDBezierSegmentFlatten(segment, &vertices, &size, &index);
        for (int v = 0; v < index; v++) {
            [flatNodes addObject:[WDBezierNode bezierNodeWithAnchorPoint:vertices[v]]];
        }
    }
    
    return flatNodes;
}

- (void) flatten
{
    self.nodes = [self flattenedNodes];
}

- (WDAbstractPath *) pathByFlatteningPath
{
    WDPath *flatPath = [[WDPath alloc] init];
    
    flatPath.nodes = [self flattenedNodes];
    
    return flatPath;
}

- (NSString *) nodeSVGRepresentation
{
    NSArray         *nodes = reversed_ ? [self reversedNodes] : nodes_;
    WDBezierNode    *node;
    NSInteger       numNodes = closed_ ? nodes.count + 1 : nodes.count;
    CGPoint         pt, prev_pt, in_pt, prev_out;
    NSMutableString *svg = [NSMutableString string];
    
    for(int i = 0; i < numNodes; i++) {
        node = nodes[(i % nodes.count)];
        
        if (i == 0) {
            pt = node.anchorPoint;
            [svg appendString:[NSString stringWithFormat:@"M%g%+g", pt.x, pt.y]];
        } else {
            pt = node.anchorPoint;
            in_pt = node.inPoint;
            
            if (prev_pt.x == prev_out.x && prev_pt.y == prev_out.y && in_pt.x == pt.x && in_pt.y == pt.y) {
            	[svg appendString:[NSString stringWithFormat:@"L%g%+g", pt.x, pt.y]];
            } else {
            	[svg appendString:[NSString stringWithFormat:@"C%g%+g%+g%+g%+g%+g",
                                   prev_out.x, prev_out.y, in_pt.x, in_pt.y, pt.x, pt.y]];
            }       
        }
        
        prev_out = node.outPoint;
        prev_pt = pt; 
    }
    
    if (closed_) {
        [svg appendString:@"Z"];
    }
    
    return svg;
}

- (id) copyWithZone:(NSZone *)zone
{       
    WDPath *path = [super copyWithZone:zone];
    
    path->nodes_ = [nodes_ mutableCopy];
    path->closed_ = closed_;
    path->reversed_ = reversed_;
    path->boundsDirty_ = YES;

    return path;
}

- (WDStrokeStyle *) effectiveStrokeStyle
{
    return self.superpath ? self.superpath.strokeStyle : self.strokeStyle;
}

- (void) addSVGArrowheadPath:(CGPathRef)pathRef toGroup:(WDXMLElement *)group
{
    WDAbstractPath  *inkpadPath = [WDAbstractPath pathWithCGPathRef:pathRef];
    WDStrokeStyle   *stroke = [self effectiveStrokeStyle];
    
    WDXMLElement *arrowPath = [WDXMLElement elementWithName:@"path"];
    [arrowPath setAttribute:@"d" value:[inkpadPath nodeSVGRepresentation]];
    [arrowPath setAttribute:@"fill" value:[stroke.color hexValue]];
    [group addChild:arrowPath];
}

- (void) addSVGArrowheadsToGroup:(WDXMLElement *)group
{
    WDStrokeStyle *stroke = [self effectiveStrokeStyle];
    
    WDArrowhead *arrow = [WDArrowhead arrowheads][stroke.startArrow];
    if (arrow) {
        CGMutablePathRef pathRef = CGPathCreateMutable();
        [arrow addToMutablePath:pathRef position:arrowStartAttachment_ scale:stroke.width angle:arrowStartAngle_
              useAdjustment:(stroke.cap == kCGLineCapButt)];
        [self addSVGArrowheadPath:pathRef toGroup:group];
        CGPathRelease(pathRef);
    }
    
    arrow = [WDArrowhead arrowheads][stroke.endArrow];
    if (arrow) {
        CGMutablePathRef pathRef = CGPathCreateMutable();
        [arrow addToMutablePath:pathRef position:arrowEndAttachment_ scale:stroke.width angle:arrowEndAngle_
              useAdjustment:(stroke.cap == kCGLineCapButt)];
        [self addSVGArrowheadPath:pathRef toGroup:group];
        CGPathRelease(pathRef);
    }
}

//#define DEBUG_ATTACHMENTS YES

- (void) renderStrokeInContext:(CGContextRef)ctx
{
    WDStrokeStyle *stroke = [self effectiveStrokeStyle];
    
    if (!stroke.hasArrow) {
        [super renderStrokeInContext:ctx];
        return;
    }
    
#ifdef DEBUG_ATTACHMENTS
    // this will show the arrowhead overlapping the stroke if the stroke color is semi-transparent
    [super renderStrokeInContext:ctx];
#else
    // normally we want the stroke and arrowhead to appear unified, even with a semi-transparent stroke color
    CGContextAddPath(ctx, self.strokePathRef);
    [stroke applyInContext:ctx];
    
    CGContextReplacePathWithStrokedPath(ctx);
#endif
    CGContextSetFillColorWithColor(ctx, stroke.color.CGColor);
    
    WDArrowhead *arrow = [WDArrowhead arrowheads][stroke.startArrow];
    if (canFitStartArrow_ && arrow) {
        [arrow addArrowInContext:ctx position:arrowStartAttachment_ scale:stroke.width angle:arrowStartAngle_
               useAdjustment:(stroke.cap == kCGLineCapButt)];
    }
    
    arrow = [WDArrowhead arrowheads][stroke.endArrow];
    if (canFitEndArrow_ && arrow) {
        [arrow addArrowInContext:ctx position:arrowEndAttachment_ scale:stroke.width angle:arrowEndAngle_
               useAdjustment:(stroke.cap == kCGLineCapButt)];
    }

    CGContextFillPath(ctx);
}

- (void) addElementsToOutlinedStroke:(CGMutablePathRef)outline
{
    WDStrokeStyle   *stroke = [self effectiveStrokeStyle];
    WDArrowhead     *arrow;
    
    if (![stroke hasArrow]) {
        // no arrows...
        return;
    }
    
    if ([stroke hasStartArrow]) {
        arrow = [WDArrowhead arrowheads][stroke.startArrow];
        [arrow addToMutablePath:outline position:arrowStartAttachment_ scale:stroke.width angle:arrowStartAngle_
              useAdjustment:(stroke.cap == kCGLineCapButt)];
    }
    
    if ([stroke hasEndArrow]) {
        arrow = [WDArrowhead arrowheads][stroke.endArrow];
        [arrow addToMutablePath:outline position:arrowEndAttachment_ scale:stroke.width angle:arrowEndAngle_
              useAdjustment:(stroke.cap == kCGLineCapButt)];
    }
}

@end

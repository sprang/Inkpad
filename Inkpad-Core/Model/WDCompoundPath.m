//
//  WDCompoundPath.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDColor.h"
#import "WDCompoundPath.h"
#import "WDFillTransform.h"
#import "WDLayer.h"
#import "WDPath.h"
#import "WDPathfinder.h"
#import "WDUtilities.h"

NSString *WDSubpathsKey = @"WDSubpathsKey";

@implementation WDCompoundPath

@synthesize subpaths = subpaths_;

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
    [coder encodeObject:subpaths_ forKey:WDSubpathsKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    subpaths_ = [coder decodeObjectForKey:WDSubpathsKey];
    
    return self; 
}

- (void) setLayer:(WDLayer *)layer
{
    [super setLayer:layer];
    
    for (WDPath *subpath in subpaths_) {
        [subpath setLayer:layer];
    }
}

- (void) awakeFromEncoding
{
    [super awakeFromEncoding];
    [subpaths_ makeObjectsPerformSelector:@selector(awakeFromEncoding) withObject:nil];
}

- (void) setSubpaths:(NSMutableArray *)subpaths
{
    [self cacheDirtyBounds];
    
    [[self.undoManager prepareWithInvocationTarget:self] setSubpaths:subpaths_];
    
    subpaths_ = subpaths;
    
    [subpaths makeObjectsPerformSelector:@selector(setSuperpath:) withObject:self];
    [subpaths makeObjectsPerformSelector:@selector(setLayer:) withObject:self.layer];
    
    [self invalidatePath];
    [self postDirtyBoundsChange];
}

// set subpaths without invalidating or notifying
- (void) setSubpathsQuiet:(NSMutableArray *)subpaths
{
    subpaths_ = subpaths;
    
    [subpaths makeObjectsPerformSelector:@selector(setSuperpath:) withObject:self];
    [subpaths makeObjectsPerformSelector:@selector(setLayer:) withObject:self.layer];
}

- (void) addSubpath:(WDPath *)path
{
    NSMutableArray *paths = [NSMutableArray array];
    
    [paths addObjectsFromArray:subpaths_];
    [paths addObject:path];
    
    self.subpaths = paths;
}

- (void) removeSubpath:(WDPath *)path
{
    NSMutableArray *paths = [NSMutableArray array];
    
    [paths addObjectsFromArray:subpaths_];
    [paths removeObject:path];
    
    self.subpaths = paths;
}

- (NSUInteger) subpathCount
{
    return self.subpaths.count;
}

- (CGRect) bounds
{
    CGRect bounds = CGRectNull;
    
    for (WDPath *path in subpaths_) {
        bounds = CGRectUnion([path bounds], bounds);
    }
    
    return bounds;
}

- (CGRect) controlBounds
{
    CGRect bounds = CGRectNull;
    
    for (WDPath *path in subpaths_) {
        bounds = CGRectUnion([path controlBounds], bounds);
    }
    
    if (self.fillTransform) {
        bounds = WDGrowRectToPoint(bounds, self.fillTransform.transformedStart);
        bounds = WDGrowRectToPoint(bounds, self.fillTransform.transformedEnd);
    }
    
    return bounds;
}

- (WDShadow *) shadowForStyleBounds
{
    // handled by subpaths
    return nil;
}

- (void) addElementsToOutlinedStroke:(CGMutablePathRef)outline
{
    for (WDPath *path in subpaths_) {
        [path addElementsToOutlinedStroke:outline];
    }
}

- (CGRect) styleBounds
{
    CGRect bounds = CGRectNull;
    
    for (WDPath *path in subpaths_) {
        bounds = CGRectUnion([path styleBounds], bounds);
    }
    
    return [self expandStyleBounds:bounds];
}

- (NSSet *) transform:(CGAffineTransform)transform
{
    [self cacheDirtyBounds];

    for (WDPath *path in subpaths_) {
        [path transform:transform];
    }
    
    // parent transforms masked elements and fill transform
    [super transform:transform];
    
    [self postDirtyBoundsChange];
    
    return nil;
}

- (BOOL) intersectsRect:(CGRect)rect
{
    for (WDPath *path in [subpaths_ reverseObjectEnumerator]) {
        if ([path intersectsRect:rect]) {
            return YES;
        }
    }
    
    return NO;
}

- (WDPickResult *) hitResultForPoint:(CGPoint)point viewScale:(float)viewScale snapFlags:(int)flags
{   
    WDPickResult        *result = [WDPickResult pickResult];
    CGRect              pointRect = WDRectFromPoint(point, kNodeSelectionTolerance / viewScale, kNodeSelectionTolerance / viewScale);
    
    if (!CGRectIntersectsRect(pointRect, [self controlBounds])) {
        return result;
    }
    
    if (flags & kWDSnapNodes) {
        // look for fill control points
        if (self.fillTransform) {
            if (WDDistance([self.fillTransform transformedStart], point) < (kNodeSelectionTolerance / viewScale)) {
                result.element = self;
                result.type = kWDFillStartPoint;
                return result;
            } else if (WDDistance([self.fillTransform transformedEnd], point) < (kNodeSelectionTolerance / viewScale)) {
                result.element = self;
                result.type = kWDFillEndPoint;
                return result;
            }
        }
    }
    
    for (WDPath *path in [subpaths_ reverseObjectEnumerator]) {
        WDPickResult *result = [path hitResultForPoint:point viewScale:viewScale snapFlags:kWDSnapEdges];
        
        if (result.type != kWDEther) {
            return result;
        }
    } 
                                                               
    if ((flags & kWDSnapFills) && (self.fill || self.maskedElements)) {
        if (CGPathContainsPoint(self.pathRef, NULL, point, self.fillRule)) {
            result.element = self;
            result.type = kWDObjectFill;
            return result;
        }
    }
    
    return [WDPickResult pickResult];
}

- (WDPickResult *) snappedPoint:(CGPoint)pt viewScale:(float)viewScale snapFlags:(int)flags
{
    for (WDPath *path in [subpaths_ reverseObjectEnumerator]) {
        WDPickResult *result = [path snappedPoint:pt viewScale:viewScale snapFlags:flags];
        
        if (result.type != kWDEther) {
            return result;
        }
    }
    
    return [WDPickResult pickResult];
}

- (CGPathRef) pathRef
{
    if (!pathRef_) {
        pathRef_ = CGPathCreateMutable();
        
        for (WDPath *subpath in subpaths_) {
            CGPathAddPath(pathRef_, NULL, subpath.pathRef);
        }
    }
    
    return pathRef_;
}

- (CGPathRef) strokePathRef
{
    if (!strokePathRef_) {
        strokePathRef_ = CGPathCreateMutable();
        
        for (WDPath *subpath in subpaths_) {
            CGPathAddPath(strokePathRef_, NULL, subpath.strokePathRef);
        }
    }
    
    return strokePathRef_;
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
}

// OpenGL-based selection rendering

- (void) drawOpenGLZoomOutlineWithViewTransform:(CGAffineTransform)viewTransform visibleRect:(CGRect)visibleRect
{
    for (WDPath *subpath in subpaths_) {
        [subpath drawOpenGLZoomOutlineWithViewTransform:viewTransform visibleRect:visibleRect];
    }
}

- (void) drawOpenGLHighlightWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    for (WDPath *subpath in subpaths_) {
        [subpath drawOpenGLHighlightWithTransform:transform viewTransform:viewTransform];
    }
}

- (void) drawOpenGLHandlesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    for (WDPath *subpath in subpaths_) {
        [subpath drawOpenGLAnchorsWithViewTransform:viewTransform];
    }
}

- (void) drawOpenGLAnchorsWithViewTransform:(CGAffineTransform)transform
{
    for (WDPath *subpath in subpaths_) {
        [subpath drawOpenGLAnchorsWithViewTransform:transform];
    }
}

- (void) addElementsToArray:(NSMutableArray *)array
{
    [super addElementsToArray:array];
    [subpaths_ makeObjectsPerformSelector:@selector(addElementsToArray:) withObject:array];
}

- (NSString *) nodeSVGRepresentation
{
    NSMutableString *svg = [NSMutableString string];
    
    for (WDPath *path in self.subpaths) {
        [svg appendString:[path nodeSVGRepresentation]];
    }
    
    return svg;
}

- (void) addSVGArrowheadsToGroup:(WDXMLElement *)group
{
    for (WDPath *path in self.subpaths) {
        [path addSVGArrowheadsToGroup:group];
    }
}

- (NSArray *) erase:(WDAbstractPath *)erasePath
{
    if (self.fill) {
        WDAbstractPath *erased = [WDPathfinder combinePaths:@[self, erasePath] operation:WDPathFinderSubtract];
        
        if (erased) {
            [erased takeStylePropertiesFrom:self];
            return @[erased];
        }
    } else {
        NSMutableArray *result = [NSMutableArray array];
        
        // erase each subpath individually
        for (WDPath *path in subpaths_) {
            [result addObjectsFromArray:[path erase:erasePath]];
        }
        
        if (result.count > 1) {
            WDCompoundPath *cp = [[WDCompoundPath alloc] init];
            [cp takeStylePropertiesFrom:self];
            cp.subpaths = result;
            
            return @[cp];
        } else if (result.count == 1) {
            WDPath *singlePath = [result lastObject];
            [singlePath takeStylePropertiesFrom:self];
            
            return @[singlePath];
        }
    }
    
    return @[];
}

- (void) simplify
{
    [subpaths_ makeObjectsPerformSelector:@selector(simplify)];
}

- (void) flatten
{
    [subpaths_ makeObjectsPerformSelector:@selector(flatten)];
}

- (WDAbstractPath *) pathByFlatteningPath
{
    WDCompoundPath *cp = [[WDCompoundPath alloc] init];
    NSMutableArray *flatPaths = [NSMutableArray array];
    
    for (WDPath *path in subpaths_) {
        [flatPaths addObject:[path pathByFlatteningPath]];
    }
    
    cp.subpaths = flatPaths;
    
    return cp;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@: subpaths: %@", [super description], subpaths_];
}

- (id) copyWithZone:(NSZone *)zone
{       
    WDCompoundPath *cp = [super copyWithZone:zone];
    
    // copy subpaths
    cp->subpaths_ = [[NSMutableArray alloc] initWithArray:subpaths_ copyItems:YES];
    [cp->subpaths_ makeObjectsPerformSelector:@selector(setSuperpath:) withObject:cp];
    
    return cp;
}

- (void) strokeStyleChanged
{
    [subpaths_ makeObjectsPerformSelector:@selector(strokeStyleChanged)];
}

- (void) renderStrokeInContext:(CGContextRef)ctx
{
    if (![self.strokeStyle hasArrow]) {
        [super renderStrokeInContext:ctx];
        return;
    }
    
    for (WDPath *path in subpaths_) {
        [path renderStrokeInContext:ctx];
    }
}

@end

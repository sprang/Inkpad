//
//  WDGroup.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDGroup.h"
#import "WDPickResult.h"

NSString *WDGroupElements = @"WDGroupElements";

@implementation WDGroup

@synthesize elements = elements_;

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:elements_ forKey:WDGroupElements];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    elements_ = [coder decodeObjectForKey:WDGroupElements];
    
    // have to do this since elements were not properly setting their groups prior to v1.3
    [elements_ makeObjectsPerformSelector:@selector(setGroup:) withObject:self];
    
    return self; 
}

- (void) tossCachedColorAdjustmentData
{
    [super tossCachedColorAdjustmentData];
    [self.elements makeObjectsPerformSelector:@selector(tossCachedColorAdjustmentData)];
}

- (void) restoreCachedColorAdjustmentData
{
    [super restoreCachedColorAdjustmentData];
    [self.elements makeObjectsPerformSelector:@selector(restoreCachedColorAdjustmentData)];
}

- (void) registerUndoWithCachedColorAdjustmentData
{
    [super registerUndoWithCachedColorAdjustmentData];
    [self.elements makeObjectsPerformSelector:@selector(registerUndoWithCachedColorAdjustmentData)];
}

- (BOOL) canAdjustColor
{
    for (WDElement *element in elements_) {
        if ([element canAdjustColor]) {
            return YES;
        }
    }
    
    return [super canAdjustColor];
}

- (void) adjustColor:(WDColor * (^)(WDColor *color))adjustment scope:(WDColorAdjustmentScope)scope
{
    for (WDElement *element in self.elements) {
        [element adjustColor:adjustment scope:scope];
    }
}

- (NSSet *) transform:(CGAffineTransform)transform
{
    [self cacheDirtyBounds];
    
    for (WDElement *element in elements_) {
        [element transform:transform];
    }
    
    [self postDirtyBoundsChange];
    return nil;
}

- (void) setElements:(NSMutableArray *)elements
{
    elements_ = elements;
    
    [elements_ makeObjectsPerformSelector:@selector(setGroup:) withObject:self];
    [elements_ makeObjectsPerformSelector:@selector(setLayer:) withObject:self.layer];
}

- (void) awakeFromEncoding
{
    [super awakeFromEncoding];
    [elements_ makeObjectsPerformSelector:@selector(awakeFromEncoding) withObject:nil];
}

- (void) setLayer:(WDLayer *)layer
{
    [super setLayer:layer];    
    [elements_ makeObjectsPerformSelector:@selector(setLayer:) withObject:layer];
}    

- (void) renderInContext:(CGContextRef)ctx metaData:(WDRenderingMetaData)metaData
{
    if (!WDRenderingMetaDataOutlineOnly(metaData)) {
        [self beginTransparencyLayer:ctx metaData:metaData];
    }
        
    for (WDElement *element in elements_) {
        [element renderInContext:ctx metaData:metaData];
    }

    if (!WDRenderingMetaDataOutlineOnly(metaData)) {
        [self endTransparencyLayer:ctx metaData:metaData];    
    }
}

- (CGRect) bounds
{
    CGRect bounds = CGRectNull;
    
    for (WDElement *element in elements_) {
        bounds = CGRectUnion([element bounds], bounds);
    }
    
    return bounds;
}

- (CGRect) styleBounds
{
    CGRect bounds = CGRectNull;
    
    for (WDElement *element in elements_) {
        bounds = CGRectUnion([element styleBounds], bounds);
    }
    
    return [self expandStyleBounds:bounds];
}

- (BOOL) intersectsRect:(CGRect)rect
{
    for (WDElement *element in [elements_ reverseObjectEnumerator]) {
        if ([element intersectsRect:rect]) {
            return YES;
        }
    }
    
    return NO;
}

// OpenGL-based selection rendering

- (void) drawOpenGLZoomOutlineWithViewTransform:(CGAffineTransform)viewTransform visibleRect:(CGRect)visibleRect
{
    for (WDElement *element in elements_) {
        [element drawOpenGLZoomOutlineWithViewTransform:viewTransform visibleRect:visibleRect];
    }
}

- (void) drawOpenGLHighlightWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    for (WDElement *element in elements_) {
        [element drawOpenGLHighlightWithTransform:transform viewTransform:viewTransform];
    }
}

- (void) drawOpenGLHandlesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    for (WDElement *element in elements_) {
        [element drawOpenGLAnchorsWithViewTransform:viewTransform];
    }
}

- (void) drawOpenGLAnchorsWithViewTransform:(CGAffineTransform)transform
{
    for (WDElement *element in elements_) {
        [element drawOpenGLAnchorsWithViewTransform:transform];
    }
}

- (WDPickResult *) hitResultForPoint:(CGPoint)pt viewScale:(float)viewScale snapFlags:(int)flags
{
    flags = flags | kWDSnapEdges;
    
    for (WDElement *element in [elements_ reverseObjectEnumerator]) {
        WDPickResult *result = [element hitResultForPoint:pt viewScale:viewScale snapFlags:flags];
        
        if (result.type != kWDEther) {
            if (!(flags & kWDSnapSubelement)) {
                result.element = self;
            }
            return result;
        }
    }
    
    return [WDPickResult pickResult];
}

- (WDPickResult *) snappedPoint:(CGPoint)pt viewScale:(float)viewScale snapFlags:(int)flags
{
    if (flags & kWDSnapSubelement) {
        for (WDElement *element in [elements_ reverseObjectEnumerator]) {
            WDPickResult *result = [element snappedPoint:pt viewScale:viewScale snapFlags:flags];
            
            if (result.type != kWDEther) {
                return result;
            }
        }
    }
    
    return [WDPickResult pickResult];
}

- (void) addElementsToArray:(NSMutableArray *)array
{
    [super addElementsToArray:array];
    [elements_ makeObjectsPerformSelector:@selector(addElementsToArray:) withObject:array];
}

- (void) addBlendablesToArray:(NSMutableArray *)array
{
    [elements_ makeObjectsPerformSelector:@selector(addBlendablesToArray:) withObject:array];
}

- (NSSet *) inspectableProperties
{
    NSMutableSet *properties = [NSMutableSet set];
    
    // we can inspect anything one of our sub-elements can inspect
    for (WDElement *element in elements_) {
        [properties unionSet:element.inspectableProperties];
    }
    
    return properties;
}

- (void) setValue:(id)value forProperty:(NSString *)property propertyManager:(WDPropertyManager *)propertyManager
{
    if ([[super inspectableProperties] containsObject:property]) {
        [super setValue:value forProperty:property propertyManager:propertyManager]; 
    } else {
        for (WDElement *element in elements_) {
            [element setValue:value forProperty:property propertyManager:propertyManager];
        }
    }
}

- (id) valueForProperty:(NSString *)property
{
    id value = nil;
    
    if ([[super inspectableProperties] containsObject:property]) {
        return [super valueForProperty:property]; 
    }
    
    // return the value for the top most object that can inspect it
    for (WDElement *element in [elements_ reverseObjectEnumerator]) {
        value = [element valueForProperty:property];
        if (value) {
            break;
        }
    }
    
    return value;
}

- (WDXMLElement *) SVGElement
{
    WDXMLElement *group = [WDXMLElement elementWithName:@"g"];
    [self addSVGOpacityAndShadowAttributes:group];
    
    for (WDElement *element in elements_) {
        [group addChild:[element SVGElement]];
    }
    
    return group;
}

- (id) copyWithZone:(NSZone *)zone
{
    WDGroup *group = [super copyWithZone:zone];
    
    group->elements_ = [[NSMutableArray alloc] initWithArray:elements_ copyItems:YES];
    [group->elements_ makeObjectsPerformSelector:@selector(setGroup:) withObject:group];
    
    return group;
}

@end

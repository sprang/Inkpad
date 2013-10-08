//
//  WDElement.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import "UIColor+Additions.h"
#import "WDColor.h"
#import "WDDrawing.h"
#import "WDElement.h"
#import "WDGLUtilities.h"
#import "WDGroup.h"
#import "WDInspectableProperties.h"
#import "WDLayer.h"
#import "WDPickResult.h"
#import "WDPropertyManager.h"
#import "WDShadow.h"
#import "WDSVGHelper.h"
#import "WDUtilities.h"

NSString *WDElementChanged = @"WDElementChanged";
NSString *WDPropertyChangedNotification = @"WDPropertyChangedNotification";
NSString *WDPropertiesChangedNotification = @"WDPropertiesChangedNotification";
NSString *WDPropertyKey = @"WDPropertyKey";
NSString *WDPropertiesKey = @"WDPropertiesKey";

NSString *WDBlendModeKey = @"WDBlendModeKey";
NSString *WDGroupKey = @"WDGroupKey";
NSString *WDLayerKey = @"WDLayerKey";
NSString *WDTransformKey = @"WDTransformKey";
NSString *WDFillKey = @"WDFillKey";
NSString *WDFillTransformKey = @"WDFillTransformKey";
NSString *WDStrokeKey = @"WDStrokeKey";

NSString *WDTextKey = @"WDTextKey";
NSString *WDFontNameKey = @"WDFontNameKey";
NSString *WDFontSizeKey = @"WDFontSizeKey";

NSString *WDObjectOpacityKey = @"WDOpacityKey";
NSString *WDShadowKey = @"WDShadowKey";

#define kAnchorRadius 4

@implementation WDElement

@synthesize layer = layer_;
@synthesize group = group_;
@synthesize opacity = opacity_;
@synthesize blendMode = blendMode_;
@synthesize shadow = shadow_;
@synthesize initialShadow = initialShadow_;

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeConditionalObject:layer_ forKey:WDLayerKey];
    
    if (group_) {
        [coder encodeConditionalObject:group_ forKey:WDGroupKey];
    }
    
    if (shadow_) {
        // If there's an initial shadow, we should save that. The user hasn't committed to the color shift yet.
        WDShadow *shadowToSave = initialShadow_ ? initialShadow_ : shadow_;
        [coder encodeObject:shadowToSave forKey:WDShadowKey];
    }
    
    if (opacity_ != 1.0f) {
        [coder encodeFloat:opacity_ forKey:WDObjectOpacityKey];
    }
	
	if (blendMode_ != kCGBlendModeNormal) {
		[coder encodeInt:blendMode_ forKey:WDBlendModeKey];
	}
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    layer_ = [coder decodeObjectForKey:WDLayerKey];
    group_ = [coder decodeObjectForKey:WDGroupKey];
    
    shadow_ = [coder decodeObjectForKey:WDShadowKey];
    
    if ([coder containsValueForKey:WDObjectOpacityKey]) {
        opacity_ = [coder decodeFloatForKey:WDObjectOpacityKey];
    } else {
        opacity_ = 1.0f;
    }
	
	blendMode_ = [coder decodeIntForKey:WDBlendModeKey] ?: kCGBlendModeNormal;
    
    return self; 
}

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }

    opacity_ = 1.0f;
    
    return self;
}

- (void) awakeFromEncoding
{
}

- (NSUndoManager *) undoManager
{
    return self.layer.drawing.undoManager;
}

- (WDDrawing *) drawing
{
    return self.layer.drawing;
}

- (void) setGroup:(WDGroup *)group
{
    if (group == group_) {
        return;
    }
    
    [[self.undoManager prepareWithInvocationTarget:self] setGroup:group_];
    group_ = group;
}

- (CGRect) bounds
{
    return CGRectZero;
}

- (CGRect) styleBounds
{
    return [self expandStyleBounds:[self bounds]];
}

- (WDShadow *) shadowForStyleBounds
{
    return self.shadow;
}

- (CGRect) expandStyleBounds:(CGRect)rect
{
    WDShadow *shadow = [self shadowForStyleBounds];
    
    if (!shadow) {
        return (self.group) ? [self.group expandStyleBounds:rect] : rect;
    }
    
    // expand by the shadow radius
    CGRect shadowRect = CGRectInset(rect, -shadow.radius, -shadow.radius);
    
    // offset
    float x = cos(shadow.angle) * shadow.offset;
    float y = sin(shadow.angle) * shadow.offset;
    shadowRect = CGRectOffset(shadowRect, x, y);
    
    // if we're in a group which has its own shadow, we need to further expand our coverage
    if (self.group) {
        shadowRect = [self.group expandStyleBounds:shadowRect];
    }
    
    return CGRectUnion(shadowRect, rect);
}

- (CGRect) subselectionBounds
{
    return [self bounds];
}

- (void) clearSubselection
{
}

- (BOOL) containsPoint:(CGPoint)pt
{
    return CGRectContainsPoint([self bounds], pt);
}

- (BOOL) intersectsRect:(CGRect)rect
{
    return CGRectIntersectsRect([self bounds], rect);
}

- (void) renderInContext:(CGContextRef)ctx metaData:(WDRenderingMetaData)metaData
{
}

- (void) addHighlightInContext:(CGContextRef)ctx
{
}

- (void) tossCachedColorAdjustmentData
{
    self.initialShadow = nil;
}

- (void) restoreCachedColorAdjustmentData
{
    if (!self.initialShadow) {
        return;
    }
    
    self.shadow = self.initialShadow;
    self.initialShadow = nil;
}

- (void) registerUndoWithCachedColorAdjustmentData
{
    if (!self.initialShadow) {
        return;
    }
    
    [(WDElement *)[self.undoManager prepareWithInvocationTarget:self] setShadow:self.initialShadow];
    self.initialShadow = nil;
}

- (void) adjustColor:(WDColor * (^)(WDColor *color))adjustment scope:(WDColorAdjustmentScope)scope
{
    if (self.shadow && scope & WDColorAdjustShadow) {
        if (!self.initialShadow) {
            self.initialShadow = self.shadow;
        }
        self.shadow = [self.initialShadow adjustColor:adjustment];
    }
}

- (NSSet *) transform:(CGAffineTransform)transform
{
    return nil;
}

// OpenGL-based selection rendering

- (void) drawOpenGLAnchorAtPoint:(CGPoint)pt transform:(CGAffineTransform)transform selected:(BOOL)selected
{
    CGPoint location = WDRoundPoint(CGPointApplyAffineTransform(pt, transform));
    CGRect anchorRect = CGRectMake(location.x - kAnchorRadius, location.y - kAnchorRadius, kAnchorRadius * 2, kAnchorRadius * 2);
    
    if (!selected) {
        glColor4f(1, 1, 1, 1);
        WDGLFillRect(anchorRect);
        [self.layer.highlightColor openGLSet];
        WDGLStrokeRect(anchorRect);
    } else {
        anchorRect = CGRectInset(anchorRect, 1, 1);
        [self.layer.highlightColor openGLSet];
        WDGLFillRect(anchorRect);
    }
}

- (void) drawOpenGLZoomOutlineWithViewTransform:(CGAffineTransform)viewTransform visibleRect:(CGRect)visibleRect
{
    if (CGRectIntersectsRect(self.bounds, visibleRect)) {
        [self drawOpenGLHighlightWithTransform:CGAffineTransformIdentity viewTransform:viewTransform];
    }
}

- (void) drawOpenGLHighlightWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
}

- (void) drawOpenGLHandlesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
}

- (void) drawOpenGLAnchorsWithViewTransform:(CGAffineTransform)transform
{
}

- (void) drawGradientControlsWithViewTransform:(CGAffineTransform)transform
{
}

- (void) drawTextPathControlsWithViewTransform:(CGAffineTransform)viewTransform;
{
}

- (void) cacheDirtyBounds
{
    dirtyBounds_ = self.styleBounds;
}

- (void) postDirtyBoundsChange
{
    if (!self.drawing) {
        return;
    }
    
    // the layer should dirty its thumbnail
    [self.layer invalidateThumbnail];
    
    NSArray *rects = @[[NSValue valueWithCGRect:dirtyBounds_], [NSValue valueWithCGRect:self.styleBounds]];
    
    NSDictionary *userInfo = @{@"rects": rects};
    [[NSNotificationCenter defaultCenter] postNotificationName:WDElementChanged object:self.drawing userInfo:userInfo];
}

- (NSSet *) alignToRect:(CGRect)rect alignment:(WDAlignment)align
{
    CGRect              bounds = [self bounds];
    CGAffineTransform	translate = CGAffineTransformIdentity;
    CGPoint             center = WDCenterOfRect(bounds);
    
    CGPoint             topLeft = rect.origin;
    CGPoint             rectCenter = WDCenterOfRect(rect);
    CGPoint             bottomRight = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    
    switch(align) {
        case WDAlignLeft:
            translate = CGAffineTransformMakeTranslation(topLeft.x - CGRectGetMinX(bounds), 0.0f);
            break;
        case WDAlignCenter:
            translate = CGAffineTransformMakeTranslation(rectCenter.x - center.x, 0.0f);
            break;
        case WDAlignRight:
            translate = CGAffineTransformMakeTranslation(bottomRight.x - CGRectGetMaxX(bounds), 0.0f);
            break;
        case WDAlignTop:
            translate = CGAffineTransformMakeTranslation(0.0f, topLeft.y - CGRectGetMinY(bounds));  
            break;
        case WDAlignMiddle:
            translate = CGAffineTransformMakeTranslation(0.0f, rectCenter.y - center.y);
            break;
        case WDAlignBottom:          
            translate = CGAffineTransformMakeTranslation(0.0f, bottomRight.y - CGRectGetMaxY(bounds));
            break;
    }
    
    [self transform:translate];
    
    return nil;
}

- (WDPickResult *) hitResultForPoint:(CGPoint)pt viewScale:(float)viewScale snapFlags:(int)flags
{
    return [WDPickResult pickResult];
}

- (WDPickResult *) snappedPoint:(CGPoint)pt viewScale:(float)viewScale snapFlags:(int)flags
{
    return [WDPickResult pickResult];
}

- (void) addElementsToArray:(NSMutableArray *)array
{
    [array addObject:self];
}

- (void) addBlendablesToArray:(NSMutableArray *)array
{
}

- (WDXMLElement *) SVGElement
{
    // must be overriden by concrete subclasses
    return nil;
}

- (void) addSVGOpacityAndShadowAttributes:(WDXMLElement *)element
{
    [element setAttribute:@"opacity" floatValue:self.opacity];
    if (blendMode_ != kCGBlendModeNormal) {
        [element setAttribute:@"inkpad:blendMode" value:[[WDSVGHelper sharedSVGHelper] displayNameForBlendMode:self.blendMode]];;
    }
    [(initialShadow_ ?: shadow_) addSVGAttributes:element];
}

- (NSSet *) changedShadowPropertiesFrom:(WDShadow *)from to:(WDShadow *)to
{
    NSMutableSet *changedProperties = [NSMutableSet set];
    
    if ((!from && to) || (!to && from)) {
        [changedProperties addObject:WDShadowVisibleProperty];
    }
    
    if (![from.color isEqual:to.color]) {
        [changedProperties addObject:WDShadowColorProperty];
    }
    if (from.angle != to.angle) {
        [changedProperties addObject:WDShadowAngleProperty];
    }
    if (from.offset != to.offset) {
        [changedProperties addObject:WDShadowOffsetProperty];
    }
    if (from.radius != to.radius) {
        [changedProperties addObject:WDShadowRadiusProperty];
    }
    
    return changedProperties;
}

- (void) setShadow:(WDShadow *)shadow
{
    if ([shadow_ isEqual:shadow]) {
        return;
    }
    
    [self cacheDirtyBounds];
    
    [(WDElement *)[self.undoManager prepareWithInvocationTarget:self] setShadow:shadow_];
    
    NSSet *changedProperties = [self changedShadowPropertiesFrom:shadow_ to:shadow];
    
    shadow_ = shadow;
    
    [self postDirtyBoundsChange];
    [self propertiesChanged:changedProperties];
}

- (void) setOpacity:(float)opacity
{
    if (opacity == opacity_) {
        return;
    }
    
    [self cacheDirtyBounds];
    
    [[self.undoManager prepareWithInvocationTarget:self] setOpacity:opacity_];
    
    opacity_ = WDClamp(0, 1, opacity);

    [self postDirtyBoundsChange];
    [self propertyChanged:WDOpacityProperty];
}

- (void) setBlendMode:(CGBlendMode)blendMode
{
	if (blendMode == blendMode_) {
		return;
	}
	
	[self cacheDirtyBounds];
	
	[[self.undoManager prepareWithInvocationTarget:self] setBlendMode:blendMode_];
	
	blendMode_ = blendMode;
	
	[self postDirtyBoundsChange];
	[self propertyChanged:WDBlendModeProperty];
}

- (void) setValue:(id)value forProperty:(NSString *)property propertyManager:(WDPropertyManager *)propertyManager
{
    if (!value) {
        return;
    }

    WDShadow *shadow = self.shadow;
    
    if ([property isEqualToString:WDOpacityProperty]) {
        self.opacity = [value floatValue];
	} else if ([property isEqualToString:WDBlendModeProperty]) {
		self.blendMode = [value intValue];
    } else if ([property isEqualToString:WDShadowVisibleProperty]) {
        if ([value boolValue] && !shadow) { // shadow enabled
            // shadow turned on and we don't have one so attach the default stroke
            self.shadow = [propertyManager defaultShadow];
        } else if (![value boolValue] && shadow) {
            self.shadow = nil;
        }
    } else if ([[NSSet setWithObjects:WDShadowColorProperty, WDShadowOffsetProperty, WDShadowRadiusProperty, WDShadowAngleProperty, nil] containsObject:property]) {
        if (!shadow) {
            shadow = [propertyManager defaultShadow];
        }
        
        if ([property isEqualToString:WDShadowColorProperty]) {
            self.shadow = [WDShadow shadowWithColor:value radius:shadow.radius offset:shadow.offset angle:shadow.angle];
        } else if ([property isEqualToString:WDShadowOffsetProperty]) {
            self.shadow = [WDShadow shadowWithColor:shadow.color radius:shadow.radius offset:[value floatValue] angle:shadow.angle];
        } else if ([property isEqualToString:WDShadowRadiusProperty]) {
            self.shadow = [WDShadow shadowWithColor:shadow.color radius:[value floatValue] offset:shadow.offset angle:shadow.angle];
        } else if ([property isEqualToString:WDShadowAngleProperty]) {
            self.shadow = [WDShadow shadowWithColor:shadow.color radius:shadow.radius offset:shadow.offset angle:[value floatValue]];
        }
    } 
}

- (id) valueForProperty:(NSString *)property
{
    if ([property isEqualToString:WDOpacityProperty]) {
        return @(opacity_);
	} else if ([property isEqualToString:WDBlendModeProperty]) {
		return @(blendMode_);
    } else if ([property isEqualToString:WDShadowVisibleProperty]) {
        return @((self.shadow) ? YES : NO);
    } else if (self.shadow) {
        if ([property isEqualToString:WDShadowColorProperty]) {
            return self.shadow.color;
        } else if ([property isEqualToString:WDShadowOffsetProperty]) {
            return @(self.shadow.offset);
        } else if ([property isEqualToString:WDShadowRadiusProperty]) {
            return @(self.shadow.radius);
        } else if ([property isEqualToString:WDShadowAngleProperty]) {
            return @(self.shadow.angle);
        }
    }
    
    return nil;
}

- (NSSet *) inspectableProperties
{
    return [NSSet setWithObjects:WDOpacityProperty, WDBlendModeProperty, WDShadowVisibleProperty,
            WDShadowColorProperty, WDShadowAngleProperty, WDShadowRadiusProperty, WDShadowOffsetProperty,
            nil];
}

- (BOOL) canInspectProperty:(NSString *)property
{
    return [[self inspectableProperties] containsObject:property];
}

- (void) propertiesChanged:(NSSet *)properties
{   
    if (self.drawing) {
        NSDictionary *userInfo = @{WDPropertiesKey: properties};
        [[NSNotificationCenter defaultCenter] postNotificationName:WDPropertiesChangedNotification object:self.drawing userInfo:userInfo];
    }
}

- (void) propertyChanged:(NSString *)property
{
    if (self.drawing) {
        NSDictionary *userInfo = @{WDPropertyKey: property};
        [[NSNotificationCenter defaultCenter] postNotificationName:WDPropertyChangedNotification object:self.drawing userInfo:userInfo];
    }
}

- (id) pathPainterAtPoint:(CGPoint)pt
{
    return [self valueForProperty:WDFillProperty];
}

- (BOOL) hasFill
{
    return ![[self valueForProperty:WDFillProperty] isEqual:[NSNull null]];
}

- (BOOL) canMaskElements
{
    return NO;
}

- (BOOL) hasEditableText
{
    return NO;
}

- (BOOL) canPlaceText
{
    return NO;
}

- (BOOL) isErasable
{
    return NO;
}

- (BOOL) canAdjustColor
{
    return self.shadow ? YES : NO;
}

- (BOOL) needsToSaveGState:(float)scale
{
    if (opacity_ != 1) {
        return YES;
    }
    
    if (shadow_ && scale <= 3) {
        return YES;
    }
	
	if (blendMode_ != kCGBlendModeNormal) {
		return YES;
	}
    
    return NO;
}

- (BOOL) needsTransparencyLayer:(float)scale
{
    return [self needsToSaveGState:scale];
}

- (void) beginTransparencyLayer:(CGContextRef)ctx metaData:(WDRenderingMetaData)metaData
{
    if (![self needsToSaveGState:metaData.scale]) {
        return;
    }
    
    CGContextSaveGState(ctx);
    
    if (opacity_ != 1) {
        CGContextSetAlpha(ctx, opacity_);
    }

    if (shadow_ && metaData.scale <= 3) {
        [shadow_ applyInContext:ctx metaData:metaData];
    }

    if (blendMode_ != kCGBlendModeNormal) {
        CGContextSetBlendMode(ctx, blendMode_);
    }
    
    if ([self needsTransparencyLayer:metaData.scale]) {     
        CGContextBeginTransparencyLayer(ctx, NULL);
    }
}

- (void) endTransparencyLayer:(CGContextRef)ctx metaData:(WDRenderingMetaData)metaData
{
    if (![self needsToSaveGState:metaData.scale]) {
        return;
    }
    
    if ([self needsTransparencyLayer:metaData.scale]) {
        CGContextEndTransparencyLayer(ctx);
    }
    
    CGContextRestoreGState(ctx);
}

- (id) copyWithZone:(NSZone *)zone
{       
    WDElement *element = [[[self class] allocWithZone:zone] init];
    
    element->shadow_ = [shadow_ copy];
    element->opacity_ = opacity_;
    element->blendMode_ = blendMode_;
    
    return element;
}

@end

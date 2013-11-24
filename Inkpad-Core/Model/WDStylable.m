//
//  WDStylable.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "UIColor+Additions.h"
#import "WDColor.h"
#import "WDFillTransform.h"
#import "WDGLUtilities.h"
#import "WDGradient.h"
#import "WDInspectableProperties.h"
#import "WDLayer.h"
#import "WDPropertyManager.h"
#import "WDStylable.h"
#import "WDSVGHelper.h"
#import "WDUtilities.h"

#define kDiamondSize        7

NSString *WDMaskedElementsKey = @"WDMaskedElementsKey";

@implementation WDStylable

@synthesize fill = fill_;
@synthesize fillTransform = fillTransform_;
@synthesize strokeStyle = strokeStyle_;
@synthesize maskedElements = maskedElements_;
@synthesize displayFillTransform = displayFillTransform_;
@synthesize initialFill = initialFill_;
@synthesize initialStroke = initialStroke_;

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    if (strokeStyle_) {
        // If there's an initial stroke, we should save that. The user hasn't committed to the color shift yet.
        WDStrokeStyle *strokeToSave = initialStroke_ ?: strokeStyle_;
        [coder encodeObject:strokeToSave forKey:WDStrokeKey];
    }
    
    // If there's an initial fill, we should save that. The user hasn't committed to the color shift yet.
    id fillToSave = initialFill_ ?: fill_;
    [coder encodeObject:fillToSave forKey:WDFillKey];
    
    if (fillTransform_) {
        [coder encodeObject:fillTransform_ forKey:WDFillTransformKey];
    }
    
    [coder encodeObject:maskedElements_ forKey:WDMaskedElementsKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    fill_ = [coder decodeObjectForKey:WDFillKey];
    fillTransform_ = [coder decodeObjectForKey:WDFillTransformKey];
    strokeStyle_ = [coder decodeObjectForKey:WDStrokeKey];
    maskedElements_ = [coder decodeObjectForKey:WDMaskedElementsKey];
    
    if (maskedElements_.count == 0) {
        // we accidentally archived an empty array instead of nil
        maskedElements_ = nil;
    }
        
    if ([fill_ transformable] && !fillTransform_) {
        // This object was created before gradient fills were supported on text.
        // For fidelity, convert the fill to a color to simulate the original rendering behavior.
        WDColor *color = [(WDGradient *)fill_ colorAtRatio:0];
        fill_ = color;
    }
    
    if (strokeStyle_ && [strokeStyle_ isNullStroke]) {
        strokeStyle_ = nil;
    }
    
    return self;
}

- (id) copyWithZone:(NSZone *)zone
{       
    WDStylable *stylable = [super copyWithZone:zone];
    
    stylable->fill_ = [(id)fill_ copy];
    stylable->fillTransform_ = [fillTransform_ copy];
    stylable->strokeStyle_ = [strokeStyle_ copy];
    
    if (maskedElements_) {
        stylable->maskedElements_ = [[NSMutableArray alloc] initWithArray:maskedElements_ copyItems:YES];
    }
    
    return stylable;
}

- (BOOL) isMasking
{
    if (!maskedElements_) {
        return NO;
    }
    
    return (maskedElements_.count > 0) ? YES : NO;
}

- (void) setMaskedElements:(NSArray *)elements
{
    [self cacheDirtyBounds];
    [[self.undoManager prepareWithInvocationTarget:self] setMaskedElements:maskedElements_];
    
    maskedElements_ = elements;
    
    [self postDirtyBoundsChange];
}

- (NSSet *) transform:(CGAffineTransform)transform
{
    self.fillTransform = [fillTransform_ transform:transform];
    
    for (WDElement *element in self.maskedElements) {
        [element transform:transform];
    }
    
    return nil;
}

- (void) addElementsToArray:(NSMutableArray *)array
{
    [super addElementsToArray:array];
    [self.maskedElements makeObjectsPerformSelector:@selector(addElementsToArray:) withObject:array];
}

- (void) addBlendablesToArray:(NSMutableArray *)array
{
    if (self.fill) {
        [array addObject:self];
    }
    
    [self.maskedElements makeObjectsPerformSelector:@selector(addBlendablesToArray:) withObject:array];
}

- (void) awakeFromEncoding
{
    [super awakeFromEncoding];
    [self.maskedElements makeObjectsPerformSelector:@selector(awakeFromEncoding) withObject:nil];
}

- (void) setLayer:(WDLayer *)layer
{
    [super setLayer:layer];
    [self.maskedElements makeObjectsPerformSelector:@selector(setLayer:) withObject:layer];
}    

- (void) drawGradientControlsWithViewTransform:(CGAffineTransform)transform
{
    if (![self fillTransform]) {
        return;
    }
    
    WDFillTransform *fT = displayFillTransform_ ? displayFillTransform_ : [self fillTransform];
    
    CGPoint start = fT.start;
    start = CGPointApplyAffineTransform(start, fT.transform);
    start = WDRoundPoint(CGPointApplyAffineTransform(start, transform));
    
    CGPoint end = fT.end;
    end = CGPointApplyAffineTransform(end, fT.transform);
    end = WDRoundPoint(CGPointApplyAffineTransform(end, transform));
    
    [self.layer.highlightColor openGLSet];
    WDGLLineFromPointToPoint(start, end);
    
    WDGLFillDiamond(start, kDiamondSize);
    WDGLFillDiamond(end, kDiamondSize);
    
    glColor4f(1, 1, 1, 1);
    WDGLFillDiamond(start, kDiamondSize - 1);
    WDGLFillDiamond(end, kDiamondSize - 1);
}

- (NSSet *) inspectableProperties
{
    static NSMutableSet *inspectableProperties = nil;
    
    if (!inspectableProperties) {
        inspectableProperties = [NSMutableSet setWithObjects:WDFillProperty, WDStrokeColorProperty,
                                 WDStrokeCapProperty, WDStrokeJoinProperty, WDStrokeWidthProperty,
                                 WDStrokeVisibleProperty, WDStrokeDashPatternProperty,
                                 WDStartArrowProperty, WDEndArrowProperty, nil];
        [inspectableProperties unionSet:[super inspectableProperties]];
    }
    
    return inspectableProperties;
}

- (NSSet *) changedStrokePropertiesFrom:(WDStrokeStyle *)from to:(WDStrokeStyle *)to
{
    NSMutableSet *changedProperties = [NSMutableSet set];
    
    if ((!from && to) || (!to && from)) {
        [changedProperties addObject:WDStrokeVisibleProperty];
    }

    if (![from.color isEqual:to.color]) {
        [changedProperties addObject:WDStrokeColorProperty];
    }
    if (from.cap != to.cap) {
        [changedProperties addObject:WDStrokeCapProperty];
    }
    if (from.join != to.join) {
        [changedProperties addObject:WDStrokeJoinProperty];
    }
    if (from.width != to.width) {
        [changedProperties addObject:WDStrokeWidthProperty];
    }
    if (![from.dashPattern isEqualToArray:to.dashPattern]) {
        [changedProperties addObject:WDStrokeDashPatternProperty];
    }
    if (![from.startArrow isEqualToString:to.startArrow]) {
        [changedProperties addObject:WDStartArrowProperty];
    }
    if (![from.endArrow isEqualToString:to.endArrow]) {
        [changedProperties addObject:WDEndArrowProperty];
    }
    
    return changedProperties;
}

- (void) strokeStyleChanged
{
    // can be overriden by subclasses
    // useful when caching style bounds
}

- (void) setStrokeStyleQuiet:(WDStrokeStyle *)strokeStyle
{
    strokeStyle_ = strokeStyle;
}

- (void) setStrokeStyle:(WDStrokeStyle *)strokeStyle 
{
    if ([strokeStyle isEqual:strokeStyle_]) {
        return;
    }
    
    [self cacheDirtyBounds];
    [[self.undoManager prepareWithInvocationTarget:self] setStrokeStyle:strokeStyle_];
    
    NSSet *changedProperties = [self changedStrokePropertiesFrom:strokeStyle_ to:strokeStyle];
    
    [self setStrokeStyleQuiet:strokeStyle];
    
    [self strokeStyleChanged];
    
    [self postDirtyBoundsChange];
    [self propertiesChanged:changedProperties];
} 

- (void) setFillQuiet:(id<WDPathPainter>)fill
{
    BOOL wasDefaultFillTransform = NO;
    
    if ([fill_ isKindOfClass:[WDGradient class]]) {
        // see if the fill transform was the default
        wasDefaultFillTransform = [self.fillTransform isDefaultInRect:self.bounds centered:[fill_ wantsCenteredFillTransform]];
    }
    
    fill_ = fill;
    
    if ([fill transformable]) {
        if (!self.fillTransform || wasDefaultFillTransform) {
            self.fillTransform = [WDFillTransform fillTransformWithRect:self.bounds centered:[fill wantsCenteredFillTransform]];
        }
    } else {
        self.fillTransform = nil;
    }
}

- (void) setFill:(id<WDPathPainter>)fill
{
    if ([fill isEqual:fill_]) {
        return;
    }
    
    [self cacheDirtyBounds];
    
    [[self.undoManager prepareWithInvocationTarget:self] setFill:fill_];

    [self setFillQuiet:fill];
    
    [self postDirtyBoundsChange];
    [self propertyChanged:WDFillProperty];
}

- (void) setFillTransform:(WDFillTransform *)fillTransform
{
    // handle nil cases
    if (self.fillTransform == fillTransform) {
        return;
    }
    
    if (self.fillTransform && [self.fillTransform isEqual:fillTransform]) {
        return;
    } 
    
    [self cacheDirtyBounds];
    [[self.undoManager prepareWithInvocationTarget:self] setFillTransform:fillTransform_];
    
    fillTransform_ = fillTransform;
    
    [self postDirtyBoundsChange];
}

- (void) setValue:(id)value forProperty:(NSString *)property propertyManager:(WDPropertyManager *)propertyManager 
{
    if (!value) {
        return;
    }
        
    WDStrokeStyle *strokeStyle = self.strokeStyle;
    
    static NSSet *strokeProperties = nil;
    if (!strokeProperties) {
        strokeProperties = [[NSSet alloc] initWithObjects:WDStrokeColorProperty, WDStrokeCapProperty, WDStrokeJoinProperty,
                            WDStrokeWidthProperty, WDStrokeDashPatternProperty, WDStartArrowProperty, WDEndArrowProperty, nil];
    }
    
    if ([property isEqualToString:WDFillProperty]) {
        if ([value isEqual:[NSNull null]]) {
            self.fill = nil;
        } else {
            self.fill = value;
        }
    } else if ([property isEqualToString:WDStrokeVisibleProperty]) {
        if ([value boolValue] && !strokeStyle) { // stroke enabled
            // stroke turned on and we don't have one so attach the default stroke
            self.strokeStyle = [propertyManager defaultStrokeStyle];
        } else if (![value boolValue] && strokeStyle) {
            self.strokeStyle = nil;
        }
    } else if ([strokeProperties containsObject:property]) {
        if (!self.strokeStyle) {
            strokeStyle = [propertyManager defaultStrokeStyle];
        }
        
        float width = [property isEqualToString:WDStrokeWidthProperty] ? [value floatValue] : strokeStyle.width;
        CGLineCap cap = [property isEqualToString:WDStrokeCapProperty]? [value intValue] : strokeStyle.cap;
        CGLineJoin join = [property isEqualToString:WDStrokeJoinProperty] ? [value intValue] : strokeStyle.join;
        WDColor *color = [property isEqualToString:WDStrokeColorProperty] ? value : strokeStyle.color;
        NSArray *dashPattern = [property isEqualToString:WDStrokeDashPatternProperty] ? value : strokeStyle.dashPattern;
        NSString *startArrow = [property isEqualToString:WDStartArrowProperty] ? value : strokeStyle.startArrow;
        NSString *endArrow = [property isEqualToString:WDEndArrowProperty] ? value : strokeStyle.endArrow;
        
        self.strokeStyle = [WDStrokeStyle strokeStyleWithWidth:width cap:cap join:join color:color
                                                   dashPattern:dashPattern startArrow:startArrow endArrow:endArrow];
    } else {
        [super setValue:value forProperty:property propertyManager:propertyManager];
    }
}

- (id) valueForProperty:(NSString *)property
{
    if (![[self inspectableProperties] containsObject:property]) {
        // we don't care about this property, let's bail
        return nil;
    }
    
    else if ([property isEqualToString:WDFillProperty]) {
        if (!self.fill) {
            return [NSNull null];
        } else {
            return self.fill;
        }
    } else if ([property isEqualToString:WDStrokeVisibleProperty]) {
        if (self.strokeStyle) {
            return @YES;
        } else {
            return @NO;
        }
    } else if (self.strokeStyle) {
        if ([property isEqualToString:WDStrokeColorProperty]) {
            return self.strokeStyle.color;
        } else if ([property isEqualToString:WDStrokeCapProperty]) {
            return @(self.strokeStyle.cap);
        } else if ([property isEqualToString:WDStrokeJoinProperty]) {
            return @(self.strokeStyle.join);
        } else if ([property isEqualToString:WDStrokeWidthProperty]) {
            return @(self.strokeStyle.width);
        } else if ([property isEqualToString:WDStrokeDashPatternProperty]) {
            return self.strokeStyle.dashPattern ?: @[];
        } else if ([property isEqualToString:WDStartArrowProperty]) {
            return self.strokeStyle.startArrow ?: WDStrokeArrowNone;
        } else if ([property isEqualToString:WDEndArrowProperty]) {
            return self.strokeStyle.endArrow ?: WDStrokeArrowNone;
        }
    }
    
    return [super valueForProperty:property];
}

- (id) pathPainterAtPoint:(CGPoint)pt
{
    id fill = [self valueForProperty:WDFillProperty];
    
    if (!fill || [fill isEqual:[NSNull null]]) {
        return [self valueForProperty:WDStrokeColorProperty];
    } else {
        return fill;
    }
}

- (void) tossCachedColorAdjustmentData
{
    self.initialStroke = nil;
    self.initialFill = nil;
    
    [self.maskedElements makeObjectsPerformSelector:@selector(tossCachedColorAdjustmentData)];
    
    [super tossCachedColorAdjustmentData];
}

- (void) restoreCachedColorAdjustmentData
{
    if (self.initialStroke) {
        self.strokeStyle = self.initialStroke;
    }
    
    if (self.initialFill) {
        self.fill = self.initialFill;
    }
    
    [super restoreCachedColorAdjustmentData];
    
    [self.maskedElements makeObjectsPerformSelector:@selector(restoreCachedColorAdjustmentData)];
    
    [self tossCachedColorAdjustmentData];
}

- (void) registerUndoWithCachedColorAdjustmentData
{
    if (self.initialStroke) {
        [[self.undoManager prepareWithInvocationTarget:self] setStrokeStyle:self.initialStroke];
    }
    
    if (self.initialFill) {
        [[self.undoManager prepareWithInvocationTarget:self] setFill:self.initialFill];
    }
    
    // call super before tossing adjustment data
    [super registerUndoWithCachedColorAdjustmentData];
    
    [self.maskedElements makeObjectsPerformSelector:@selector(registerUndoWithCachedColorAdjustmentData)];
    
    [self tossCachedColorAdjustmentData];
}

- (BOOL) canAdjustColor
{
    if (self.fill || self.strokeStyle) {
        return YES;
    }
    
    for (WDElement *element in self.maskedElements) {
        if ([element canAdjustColor]) {
            return YES;
        }
    }
    
    return [super canAdjustColor];
}

- (void) adjustColor:(WDColor * (^)(WDColor *color))adjustment scope:(WDColorAdjustmentScope)scope
{
    if (self.fill && scope & WDColorAdjustFill) {
        if (!self.initialFill) {
            self.initialFill = self.fill;
        }
        self.fill = [self.initialFill adjustColor:adjustment];
    }
    
    if (self.strokeStyle && scope & WDColorAdjustStroke) {
        if (!self.initialStroke) {
            self.initialStroke = self.strokeStyle;
        }
        self.strokeStyle = [self.initialStroke adjustColor:adjustment];
    }
    
    for (WDElement *element in self.maskedElements) {
        [element adjustColor:adjustment scope:scope];
    }
    
    [super adjustColor:adjustment scope:scope];
}

- (void) addSVGFillAndStrokeAttributes:(WDXMLElement *)element
{
    [self addSVGFillAttributes:element];

    if (self.strokeStyle) {
        [self.strokeStyle addSVGAttributes:element];
    }
}

- (void) addSVGFillAttributes:(WDXMLElement *)element
{
    if (!fill_) {
        [element setAttribute:@"fill" value:@"none"];
        return;
    }
    
    if ([fill_ isKindOfClass:[WDColor class]]) {
        WDColor *color = (WDColor *) fill_;
        
        [element setAttribute:@"fill" value:[color hexValue]];
        
        if (color.alpha != 1) {
            [element setAttribute:@"fill-opacity" floatValue:color.alpha];
        }
    } else if ([fill_ isKindOfClass:[WDGradient class]]) {
        WDGradient *gradient = (WDGradient *)fill_;
        NSString *uniqueID = [[WDSVGHelper sharedSVGHelper] uniqueIDWithPrefix:(gradient.type == kWDRadialGradient ? @"RadialGradient" : @"LinearGradient")];
        
        [[WDSVGHelper sharedSVGHelper] addDefinition:[gradient SVGElementWithID:uniqueID fillTransform:self.fillTransform]];
        
        [element setAttribute:@"fill" value:[NSString stringWithFormat:@"url(#%@)", uniqueID]];
    }
}

- (BOOL) canMaskElements
{
    return YES;
}

- (void) takeStylePropertiesFrom:(WDStylable *)obj
{
    self.fill = obj.fill;
    self.fillTransform = obj.fillTransform;
    self.strokeStyle = obj.strokeStyle;
    self.opacity = obj.opacity;
    self.shadow = obj.shadow;
    self.maskedElements = obj.maskedElements;
}

- (BOOL) needsTransparencyLayer:(float)scale
{
    if (self.maskedElements) {
        return YES;
    }
    
    if (self.fill && self.strokeStyle) {
        return YES;
    }
    
    if ([self.fill isKindOfClass:[WDGradient class]] && self.shadow) {
        return YES;
    }
    
    return NO;
}

@end

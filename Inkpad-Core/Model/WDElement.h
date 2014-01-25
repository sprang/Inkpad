//
//  WDElement.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import <Foundation/Foundation.h>
#import "WDDrawing.h"
#import "WDXMLElement.h"

#if TARGET_OS_IPHONE
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#else 
#import <OpenGL/gl.h>
#endif

typedef enum {
    WDAlignLeft,
    WDAlignCenter,
    WDAlignRight,
    WDAlignTop,
    WDAlignMiddle,
    WDAlignBottom
} WDAlignment;

typedef enum {
    WDColorAdjustStroke = 1 << 0,
    WDColorAdjustFill   = 1 << 1,
    WDColorAdjustShadow = 1 << 2
} WDColorAdjustmentScope;

@class WDGroup;
@class WDLayer;
@class WDPickResult;
@class WDPropertyManager;
@class WDShadow;
@class WDXMLElement;

@interface WDElement : NSObject <NSCoding, NSCopying> {
    CGRect      dirtyBounds_;
}

@property (nonatomic, weak) WDLayer *layer;
@property (nonatomic, weak) WDGroup *group;  // pointer to parent group, if any
@property (nonatomic, assign) float opacity;
@property (nonatomic, assign) CGBlendMode blendMode;
@property (nonatomic, strong) WDShadow *shadow;
@property (nonatomic, strong) WDShadow *initialShadow;
@property (weak, nonatomic, readonly) NSUndoManager *undoManager;
@property (weak, nonatomic, readonly) WDDrawing *drawing;
@property (weak, nonatomic, readonly) NSSet *inspectableProperties;

- (void) awakeFromEncoding;

- (CGRect) bounds;
- (CGRect) styleBounds;
- (WDShadow *) shadowForStyleBounds;
- (CGRect) expandStyleBounds:(CGRect)rect;

- (CGRect) subselectionBounds;
- (void) clearSubselection;

- (BOOL) containsPoint:(CGPoint)pt;
- (BOOL) intersectsRect:(CGRect)rect;

- (void) renderInContext:(CGContextRef)ctx metaData:(WDRenderingMetaData)metaData;

- (void) cacheDirtyBounds;
- (void) postDirtyBoundsChange;

- (void) tossCachedColorAdjustmentData;
- (void) restoreCachedColorAdjustmentData;
- (void) registerUndoWithCachedColorAdjustmentData;

// OpenGL-based selection rendering
- (void) drawOpenGLZoomOutlineWithViewTransform:(CGAffineTransform)viewTransform visibleRect:(CGRect)visibleRect;
- (void) drawOpenGLAnchorAtPoint:(CGPoint)pt transform:(CGAffineTransform)transform selected:(BOOL)selected;
- (void) drawOpenGLHighlightWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform;
- (void) drawOpenGLHandlesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform;
- (void) drawOpenGLAnchorsWithViewTransform:(CGAffineTransform)transform;
- (void) drawGradientControlsWithViewTransform:(CGAffineTransform)transform;
- (void) drawTextPathControlsWithViewTransform:(CGAffineTransform)viewTransform viewScale:(float)viewScale;

- (NSSet *) transform:(CGAffineTransform)transform;
- (void) adjustColor:(WDColor * (^)(WDColor *color))adjustment scope:(WDColorAdjustmentScope)scope;

- (NSSet *) alignToRect:(CGRect)rect alignment:(WDAlignment)align;

- (WDPickResult *) hitResultForPoint:(CGPoint)pt viewScale:(float)viewScale snapFlags:(int)flags;
- (WDPickResult *) snappedPoint:(CGPoint)pt viewScale:(float)viewScale snapFlags:(int)flags;

- (void) addBlendablesToArray:(NSMutableArray *)array;
- (void) addElementsToArray:(NSMutableArray *)array;

- (WDXMLElement *) SVGElement;
- (void) addSVGOpacityAndShadowAttributes:(WDXMLElement *)element;

- (BOOL) canMaskElements;
- (BOOL) hasEditableText;
- (BOOL) canPlaceText;
- (BOOL) isErasable;
- (BOOL) canAdjustColor;

// inspection
- (void) setValue:(id)value forProperty:(NSString *)property propertyManager:(WDPropertyManager *)propertyManager;
- (id) valueForProperty:(NSString *)property;
- (NSSet *) inspectableProperties;
- (BOOL) canInspectProperty:(NSString *)property;
- (void) propertyChanged:(NSString *)property;
- (void) propertiesChanged:(NSSet *)property;
- (id) pathPainterAtPoint:(CGPoint)pt;
- (BOOL) hasFill;

- (BOOL) needsToSaveGState:(float)scale;
- (BOOL) needsTransparencyLayer:(float)scale;

- (void) beginTransparencyLayer:(CGContextRef)ctx metaData:(WDRenderingMetaData)metaData;
- (void) endTransparencyLayer:(CGContextRef)ctx metaData:(WDRenderingMetaData)metaData;

@end

extern NSString *WDElementChanged;
extern NSString *WDPropertyChangedNotification;
extern NSString *WDPropertiesChangedNotification;

extern NSString *WDPropertyKey;
extern NSString *WDPropertiesKey;
extern NSString *WDTransformKey;
extern NSString *WDFillKey;
extern NSString *WDFillTransformKey;
extern NSString *WDStrokeKey;

extern NSString *WDTextKey;
extern NSString *WDFontNameKey;
extern NSString *WDFontSizeKey;

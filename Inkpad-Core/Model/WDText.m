//
//  WDText.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#if !TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import "NSCoderAdditions.h"
#endif

#import <CoreText/CoreText.h>
#import "NSString+Additions.h"
#import "UIColor+Additions.h"
#import "WDColor.h"
#import "WDFillTransform.h"
#import "WDFontManager.h"
#import "WDGLUtilities.h"
#import "WDGradient.h"
#import "WDInspectableProperties.h"
#import "WDLayer.h"
#import "WDPath.h"
#import "WDPropertyManager.h"
#import "WDSVGHelper.h"
#import "WDText.h"
#import "WDUtilities.h"

#define kMinWidth 20
#define kDiamondSize 7

NSString *WDWidthKey = @"WDWidthKey";
NSString *WDAlignmentKey = @"WDAlignmentKey";

@interface WDText (Private)
- (void) invalidate;
- (void) invalidatePreservingAttributedString:(BOOL)flag;
@end

@implementation WDText

@synthesize fontSize = fontSize_;
@synthesize fontName = fontName_;
@synthesize width = width_;
@synthesize transform = transform_;
@synthesize text = text_;
@synthesize alignment = alignment_;
@synthesize attributedString;

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeFloat:width_ forKey:WDWidthKey];
    [coder encodeCGAffineTransform:transform_ forKey:WDTransformKey];
    [coder encodeObject:text_ forKey:WDTextKey];
    [coder encodeObject:fontName_ forKey:WDFontNameKey];
    [coder encodeFloat:fontSize_ forKey:WDFontSizeKey];
    [coder encodeInt32:alignment_ forKey:WDAlignmentKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    width_ = [coder decodeFloatForKey:WDWidthKey];
    transform_ = [coder decodeCGAffineTransformForKey:WDTransformKey];
    text_ = [coder decodeObjectForKey:WDTextKey];
    alignment_ = [coder decodeInt32ForKey:WDAlignmentKey]; 

    fontName_ = [coder decodeObjectForKey:WDFontNameKey];
    fontSize_ = [coder decodeFloatForKey:WDFontSizeKey];
    
    if (![[WDFontManager sharedInstance] validFont:fontName_]) {
        fontName_ = @"Helvetica";
    }
    
    needsLayout_ = YES;
    naturalBoundsDirty_ = YES;
    
    return self; 
}

+ (float) minimumWidth
{
    return kMinWidth;
}

- (CTFontRef) fontRef
{
    if (!fontRef_) {
        fontRef_ = [[WDFontManager sharedInstance] newFontRefForFont:fontName_ withSize:fontSize_ provideDefault:YES];
    }
    
    return fontRef_;
}

- (CGRect) naturalBounds
{
    if (fontName_ && naturalBoundsDirty_) {
        CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef) self.attributedString);
        CFRange fitRange;
        
        // compute size
        CGSize naturalSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(width_, CGFLOAT_MAX), &fitRange);
        
        // clean up
        CFRelease(framesetter);
        
        float fontHeight = CTFontGetLeading([self fontRef]);
        naturalBounds_ = CGRectMake(0, 0, width_, MAX(fontHeight, naturalSize.height + 1));
        naturalBoundsDirty_ =  NO;
    }
    
    return naturalBounds_;
}

- (CGRect) bounds
{
    return CGRectApplyAffineTransform(self.naturalBounds, transform_);
}

- (void) layout
{
    if (!needsLayout_ || !fontName_ || !text_) {
        return;
    }
    
    // compute glyph positions and angles and determine style bounds
    if (!glyphs_) {
        glyphs_ = [[NSMutableArray alloc] init];
    }
    [glyphs_ removeAllObjects];
    
    styleBounds_ = CGRectNull;
    
    CGRect naturalBounds = self.naturalBounds;
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, naturalBounds);
    
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef) self.attributedString);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFRelease(framesetter);
    CFRelease(path);
    
    NSArray *lines = (NSArray *) CTFrameGetLines(frame);
    CGPoint origins[lines.count];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, lines.count), origins);
    
    for (int i = 0; i < lines.count; i++) {
        CTLineRef lineRef = (__bridge CTLineRef) lines[i]; 
        NSArray *glyphRuns = (NSArray *) CTLineGetGlyphRuns(lineRef);
        
        for (int n = 0; n < glyphRuns.count; n++) {
            CTRunRef glyphRun = (__bridge CTRunRef) glyphRuns[n];
            CFIndex glyphCount = CTRunGetGlyphCount(glyphRun);
            
            CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(glyphRun), kCTFontAttributeName);
            
            CGGlyph buffer[glyphCount];
            CGPoint pts[glyphCount];
            CTRunGetGlyphs(glyphRun, CFRangeMake(0, 0), buffer);
            CTRunGetPositions(glyphRun, CFRangeMake(0,0), pts);
            
            for (int t = 0; t < glyphCount; t++) {
                CGPoint position = CGPointMake(CGRectGetMinX(naturalBounds) + origins[i].x, CGRectGetMaxY(naturalBounds) - origins[i].y);
                position = WDAddPoints(position, pts[t]);
                
                CGAffineTransform tX = transform_;
                tX = CGAffineTransformTranslate(tX, position.x, position.y);
                tX = CGAffineTransformScale(tX, 1, -1);
                
                CGPathRef glyphPath = CTFontCreatePathForGlyph(runFont, buffer[t], &tX);
                
                if (!glyphPath) {
                    continue;
                } else if (CGPathIsEmpty(glyphPath)) {
                    CGPathRelease(glyphPath);
                    continue;
                }
                
                styleBounds_ = CGRectUnion(styleBounds_, WDStrokeBoundsForPath(glyphPath, self.strokeStyle));
                [glyphs_ addObject:(__bridge id) glyphPath];
                
                CGPathRelease(glyphPath);
            }
        }
    }
    
    needsLayout_ = NO;
    CFRelease(frame);
}

- (CGRect) styleBounds
{
    [self layout];
    return CGRectUnion([self expandStyleBounds:styleBounds_], self.bounds);
}

- (CGRect) controlBounds
{
    CGRect bbox = self.bounds;
    
    if (self.fillTransform) {
        bbox = WDGrowRectToPoint(bbox, self.fillTransform.transformedStart);
        bbox = WDGrowRectToPoint(bbox, self.fillTransform.transformedEnd);
    }
    
    return bbox;
}

- (CGMutablePathRef) pathRef
{
    if (!pathRef_) {
        pathRef_ = CGPathCreateMutable();
        CGPathAddRect(pathRef_, &transform_, self.naturalBounds);
    }
    
    return pathRef_;
}

- (void) dealloc
{
    if (pathRef_) {
        CGPathRelease(pathRef_);
        pathRef_ = NULL;
    }
    
    if (fontRef_) {
        CFRelease(fontRef_);
        fontRef_ = NULL;
    }
}

- (BOOL) containsPoint:(CGPoint)pt
{
    return CGPathContainsPoint(self.pathRef, NULL, pt, 0);
}

- (BOOL) intersectsRect:(CGRect)rect
{
    CGPoint     ul, ur, lr, ll;
    CGRect      naturalBounds = self.naturalBounds;
    
    ul = CGPointZero;
    ur = CGPointMake(width_, 0);
    lr = CGPointMake(width_, CGRectGetHeight(naturalBounds));
    ll = CGPointMake(0, CGRectGetHeight(naturalBounds));
    
    ul = CGPointApplyAffineTransform(ul, transform_);
    ur = CGPointApplyAffineTransform(ur, transform_);
    lr = CGPointApplyAffineTransform(lr, transform_);
    ll = CGPointApplyAffineTransform(ll, transform_);
    
    return (WDLineInRect(ul, ur, rect) ||
            WDLineInRect(ur, lr, rect) ||
            WDLineInRect(lr, ll, rect) ||
            WDLineInRect(ll, ul, rect));
}

- (void) drawTextInContext:(CGContextRef)ctx drawingMode:(CGTextDrawingMode)mode
{
    [self drawTextInContext:ctx drawingMode:mode didClip:NULL];
}

- (void) drawTextInContext:(CGContextRef)ctx drawingMode:(CGTextDrawingMode)mode didClip:(BOOL *)didClip
{
    [self layout];

    for (id pathRef in glyphs_) {
        CGPathRef glyphPath = (__bridge CGPathRef) pathRef;
        
        if (mode == kCGTextStroke) {
            CGPathRef sansQuadratics = WDCreateCubicPathFromQuadraticPath(glyphPath);
            CGContextAddPath(ctx, sansQuadratics);
            CGPathRelease(sansQuadratics);
            
            // stroke each glyph immediately for better performance
            CGContextSaveGState(ctx);
            CGContextStrokePath(ctx);
            CGContextRestoreGState(ctx);
        } else {
            CGContextAddPath(ctx, glyphPath);
        }
    }

    if (mode == kCGTextClip && !CGContextIsPathEmpty(ctx)) {
        if (didClip) {
            *didClip = YES; 
        }
        CGContextClip(ctx);
    }

    if (mode == kCGTextFill) {
        CGContextFillPath(ctx);
    }
}

- (void) renderInContext:(CGContextRef)ctx metaData:(WDRenderingMetaData)metaData
{
    UIGraphicsPushContext(ctx);
    
    if (metaData.flags & WDRenderOutlineOnly) {
        CGContextAddPath(ctx, self.pathRef);
        CGContextStrokePath(ctx);
        
        [self drawTextInContext:ctx drawingMode:kCGTextFill];
    } else if ([self.strokeStyle willRender] || self.fill || self.maskedElements) {
        [self beginTransparencyLayer:ctx metaData:metaData];
        
        if (self.fill) {
            CGContextSaveGState(ctx);
            [self.fill paintText:self inContext:ctx];
            CGContextRestoreGState(ctx);
        }
        
        if (self.maskedElements) {
            BOOL didClip = NO;
            
            CGContextSaveGState(ctx);
            // clip to the mask boundary
            [self drawTextInContext:ctx drawingMode:kCGTextClip didClip:&didClip];
            
            if (didClip) {
                // draw all the elements inside the mask
                for (WDElement *element in self.maskedElements) {
                    [element renderInContext:ctx metaData:metaData];
                }
            }
            
            CGContextRestoreGState(ctx);
        }
        
        if ([self.strokeStyle willRender]) {
            [self.strokeStyle applyInContext:ctx];
            [self drawTextInContext:ctx drawingMode:kCGTextStroke];
        }
        
        [self endTransparencyLayer:ctx metaData:metaData];
    }
    
    UIGraphicsPopContext();
}

- (BOOL) hasEditableText
{
    return YES;
}

- (void) cacheOriginalText
{
    cachedText_ = [self.text copy];
}

- (void) registerUndoWithCachedText
{
    if ([cachedText_ isEqualToString:text_]) {
        return;
    }
    
    [[self.undoManager prepareWithInvocationTarget:self] setText:cachedText_];
    cachedText_ = nil;
}

- (void) cacheTransformAndWidth
{
    [self cacheDirtyBounds];
    cachedTransform_ = transform_;
    cachedWidth_ = width_;
    
    cachingWidth_ = YES;
}

- (void) registerUndoWithCachedTransformAndWidth
{
    [(WDText *)[self.undoManager prepareWithInvocationTarget:self] setTransform:cachedTransform_];
    [(WDText *)[self.undoManager prepareWithInvocationTarget:self] setWidth:cachedWidth_];
    
    [self postDirtyBoundsChange];
    
    cachingWidth_ = NO;
}

- (void) invalidate
{
    [self invalidatePreservingAttributedString:NO];
}

- (void) invalidatePreservingAttributedString:(BOOL)flag
{
    if (!flag) {
        attributedString = nil;
    }
    
    CGPathRelease(pathRef_);
    pathRef_ = NULL;
    
    needsLayout_ = YES;
    naturalBoundsDirty_ = YES;
    
    [self postDirtyBoundsChange];
}

- (void) setTextQuiet:(NSString *)text
{
    text_ = text;
    
    [self invalidate];
}

- (void) setText:(NSString *)text
{
    if ([text isEqualToString:text_]) {
        return;
    }
    
    [self cacheDirtyBounds];
    
    if (!cachedText_) {
        [[self.undoManager prepareWithInvocationTarget:self] setText:text_];
    }
    
    [self setTextQuiet:text];
}

- (void) setFontNameQuiet:(NSString *)fontName
{
    fontName_ = fontName;
    
    if (fontRef_) {
        CFRelease(fontRef_);
        fontRef_ = NULL;
    }
}

- (void) setFontName:(NSString *)fontName
{
    [self cacheDirtyBounds];
    
    [[self.undoManager prepareWithInvocationTarget:self] setFontName:fontName_];

    [self setFontNameQuiet:fontName];
    
    [self invalidate];
    
    [self propertiesChanged:[NSSet setWithObjects:WDFontNameProperty, nil]];
}

- (void) setFontSizeQuiet:(float)size
{
    fontSize_ = size;
    
    if (fontRef_) {
        CFRelease(fontRef_);
        fontRef_ = NULL;
    }
}

- (void) setFontSize:(float)size
{
    [self cacheDirtyBounds];
    
    [(WDText *)[self.undoManager prepareWithInvocationTarget:self] setFontSize:fontSize_];

    [self setFontSizeQuiet:size];
    
    [self invalidate];
    
    [self propertiesChanged:[NSSet setWithObjects:WDFontSizeProperty, nil]];
}

- (void) setWidthQuiet:(float)width
{
    width_ = width;
}

- (void) setWidth:(float)width
{
    [self cacheDirtyBounds];
    
    [(WDText *)[self.undoManager prepareWithInvocationTarget:self] setWidth:width_];
    
    [self setWidthQuiet:width];
    
    [self invalidate];
}

- (void) setAlignment:(NSTextAlignment)alignment
{
    [self cacheDirtyBounds];
    
    [(WDText *)[self.undoManager prepareWithInvocationTarget:self] setAlignment:alignment_];
    alignment_ = alignment;
    
    [self invalidate];
    
    [self propertyChanged:WDTextAlignmentProperty];
}

- (NSSet *) inspectableProperties
{
    static NSMutableSet *inspectableProperties = nil;
    
    if (!inspectableProperties) {
        inspectableProperties = [NSMutableSet setWithObjects:WDFontNameProperty, WDFontSizeProperty, WDTextAlignmentProperty, nil];
        [inspectableProperties unionSet:[super inspectableProperties]];
    }
    
    return inspectableProperties;
}

- (void) setValue:(id)value forProperty:(NSString *)property propertyManager:(WDPropertyManager *)propertyManager 
{
    if (![[self inspectableProperties] containsObject:property]) {
        // we don't care about this property, let's bail
        return [super setValue:value forProperty:property propertyManager:propertyManager];
    }
    
    if ([property isEqualToString:WDFontNameProperty]) {
        [self setFontName:value];
    } else if ([property isEqualToString:WDFontSizeProperty]) {
        [self setFontSize:[value intValue]];
    } else if ([property isEqualToString:WDTextAlignmentProperty]) {
        [self setAlignment:[value intValue]];
    } else {
        [super setValue:value forProperty:property propertyManager:propertyManager];
    }
}

- (id) valueForProperty:(NSString *)property
{
    if (![[self inspectableProperties] containsObject:property]) {
        // we don't care about this property, let's bail
        return [super valueForProperty:property];
    }
    
    if ([property isEqualToString:WDFontNameProperty]) {
        return fontName_;
    } else if ([property isEqualToString:WDFontSizeProperty]) {
        return @(fontSize_);
    } else if ([property isEqualToString:WDTextAlignmentProperty]) {
        return @(alignment_);
    } else {
        return [super valueForProperty:property];
    }
    
    return nil;
}

- (void) setTransformQuiet:(CGAffineTransform)transform
{
    transform_ = transform;
}

- (void) setTransform:(CGAffineTransform)transform
{
    [self cacheDirtyBounds];
    
    [(WDText *)[self.undoManager prepareWithInvocationTarget:self] setTransform:transform_];
    
    [self setTransformQuiet:transform];
    
    [self invalidatePreservingAttributedString:YES];
}

- (NSSet *) transform:(CGAffineTransform)transform
{
    [super transform:transform];
    self.transform = CGAffineTransformConcat(transform_, transform);
    return nil;
}

- (void) drawOpenGLZoomOutlineWithViewTransform:(CGAffineTransform)viewTransform visibleRect:(CGRect)visibleRect
{
    if (CGRectIntersectsRect(self.bounds, visibleRect)) {
        [self drawOpenGLHighlightWithTransform:CGAffineTransformIdentity viewTransform:viewTransform];
        [self drawOpenGLTextOutlinesWithTransform:CGAffineTransformIdentity viewTransform:viewTransform];
    }
}

- (void) drawOpenGLHighlightWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    CGAffineTransform   tX;
    CGPoint             ul, ur, lr, ll;
    CGRect              naturalBounds = self.naturalBounds;
    
    tX = CGAffineTransformConcat(transform_, transform);
    tX = CGAffineTransformConcat(tX, viewTransform);
    
    ul = CGPointZero;
    ur = CGPointMake(CGRectGetWidth(naturalBounds), 0);
    lr = CGPointMake(CGRectGetWidth(naturalBounds), CGRectGetHeight(naturalBounds));
    ll = CGPointMake(0, CGRectGetHeight(naturalBounds));
    
    ul = CGPointApplyAffineTransform(ul, tX);
    ur = CGPointApplyAffineTransform(ur, tX);
    lr = CGPointApplyAffineTransform(lr, tX);
    ll = CGPointApplyAffineTransform(ll, tX);
    
    // draw outline
    [self.layer.highlightColor openGLSet];
    
    WDGLLineFromPointToPoint(ul, ur);
    WDGLLineFromPointToPoint(ur, lr);
    WDGLLineFromPointToPoint(lr, ll);
    WDGLLineFromPointToPoint(ll, ul);
    
    if (!CGAffineTransformIsIdentity(transform) || cachingWidth_) {
        [self drawOpenGLTextOutlinesWithTransform:transform viewTransform:viewTransform];
    }
}

- (void) drawOpenGLAnchorsWithViewTransform:(CGAffineTransform)transform
{
    CGPoint left, right;
    
    left = CGPointMake(0, CGRectGetHeight(self.naturalBounds) / 2);
    right = CGPointMake(width_, CGRectGetHeight(self.naturalBounds) / 2);
    
    left = CGPointApplyAffineTransform(left, transform_);
    right = CGPointApplyAffineTransform(right, transform_);
    
    [self drawOpenGLAnchorAtPoint:left transform:transform selected:YES];
    [self drawOpenGLAnchorAtPoint:right transform:transform selected:YES];
}

- (void) drawOpenGLHandlesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    CGPoint left, right;
    
    left = CGPointMake(0, CGRectGetHeight(self.naturalBounds) / 2);
    right = CGPointMake(width_, CGRectGetHeight(self.naturalBounds) / 2);
    
    left = CGPointApplyAffineTransform(left, transform_);
    right = CGPointApplyAffineTransform(right, transform_);
    
    [self drawOpenGLAnchorAtPoint:left transform:viewTransform selected:NO];
    [self drawOpenGLAnchorAtPoint:right transform:viewTransform selected:NO];
}

- (WDPickResult *) snapEdges:(CGPoint)point viewScale:(float)viewScale
{
    WDPickResult        *result = [WDPickResult pickResult];
    WDBezierSegment     segment;
    CGPoint             corner[4];
    CGPoint             nearest;
    CGRect              naturalBounds = self.naturalBounds;
    
    corner[0] = CGPointZero;
    corner[1] = CGPointMake(CGRectGetWidth(naturalBounds), 0);
    corner[2] = CGPointMake(CGRectGetWidth(naturalBounds), CGRectGetHeight(naturalBounds));
    corner[3] = CGPointMake(0, CGRectGetHeight(naturalBounds));

    for (int i = 0; i < 4; i++) {
        segment.a_ = segment.out_ = CGPointApplyAffineTransform(corner[i], transform_);
        segment.b_ = segment.in_ = CGPointApplyAffineTransform(corner[(i+1) % 4], transform_);
        
        if (WDBezierSegmentFindPointOnSegment(segment, point, kNodeSelectionTolerance / viewScale, &nearest, NULL)) {
            result.element = self;
            result.type = kWDEdge;
            result.snappedPoint = nearest;
            
            return result;
        }
    }
    
    return result;
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
        CGPoint left, right;
        
        // check gradient control handles first (if any)
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
            
        
        left = CGPointMake(0, CGRectGetHeight(self.naturalBounds) / 2);
        right = CGPointMake(width_, CGRectGetHeight(self.naturalBounds) / 2);
        
        left = CGPointApplyAffineTransform(left, transform_);
        right = CGPointApplyAffineTransform(right, transform_);
        
        
        distance = WDDistance(left, point);
        if (distance < MIN(tolerance, minDistance)) {
            result.element = self;
            result.type = kWDLeftTextKnob;
        }
        
        distance = WDDistance(right, point);
        if (distance < MIN(tolerance, minDistance)) {
            result.element = self;
            result.type = kWDRightTextKnob;
        }
        
        if (result.type != kWDEther) {
            result.element = self;
            return result;
        }
    }
    
    if (flags & kWDSnapEdges) {
        result = [self snapEdges:point viewScale:viewScale];
        
        if (result.snapped) {
            return result;
        }
    }
    
    if (flags & kWDSnapFills) {
        if (CGPathContainsPoint(self.pathRef, NULL, point, true)) {
            result.element = self;
            result.type = kWDObjectFill;
            return result;
        }
    }
    
    return result;
}

- (void) moveHandle:(NSUInteger)handle toPoint:(CGPoint)pt
{
    CGPoint             left = CGPointMake(0, CGRectGetHeight(self.naturalBounds) / 2);
    CGPoint             right = CGPointMake(width_, CGRectGetHeight(self.naturalBounds) / 2);
    CGAffineTransform   invert = CGAffineTransformInvert(transform_);
    CGPoint             mappedPoint = CGPointApplyAffineTransform(pt, invert);
    BOOL                accepted = NO;
    float               newWidth;
    
    if (handle == kWDRightTextKnob) {
        newWidth = mappedPoint.x - left.x;
        if (newWidth >= kMinWidth) {
            width_ = newWidth;
            accepted = YES;
        }
    } else if (handle == kWDLeftTextKnob) {
        newWidth = right.x - mappedPoint.x;
        
        if (newWidth >= kMinWidth) {
            CGAffineTransform shift = CGAffineTransformMakeTranslation(width_ - newWidth, 0);
            transform_ = CGAffineTransformConcat(shift, transform_);
            width_ = newWidth;
            accepted = YES;
        }
    }
    
    if (accepted) {
        attributedString = nil;
        
        CGPathRelease(pathRef_);
        pathRef_ = NULL;
        
        needsLayout_ = YES;
        naturalBoundsDirty_ = YES;
    }
}

- (NSAttributedString *) attributedString
{
    if (!text_ || !fontName_) {
        return nil;
    }
    
    if (!attributedString) {
        CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
        
        CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), (CFStringRef)text_);    
        CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength((CFStringRef)text_)), kCTFontAttributeName, [self fontRef]);
        
        // paint with the foreground color
        CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength((CFStringRef)text_)), kCTForegroundColorFromContextAttributeName, kCFBooleanTrue);
        
        CTTextAlignment alignment;
        
        switch (alignment_) {
            case NSTextAlignmentLeft: alignment = kCTLeftTextAlignment; break;
            case NSTextAlignmentRight: alignment = kCTRightTextAlignment; break;
            case NSTextAlignmentCenter: alignment = kCTCenterTextAlignment; break;
            default: alignment = kCTLeftTextAlignment; break;
        }
		
        CTParagraphStyleSetting settings[] = {
            {kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment}
        };
        CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(settings, sizeof(settings) / sizeof(settings[0]));
        CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength((CFStringRef)attrString)), kCTParagraphStyleAttributeName, paragraphStyle);    
        CFRelease(paragraphStyle);
        
        attributedString = (NSAttributedString *) CFBridgingRelease(attrString);
    }
    
    return attributedString;
}

- (void) addSVGFillAttributes:(WDXMLElement *)element
{
    if ([self.fill isKindOfClass:[WDGradient class]]) {
        WDGradient *gradient = (WDGradient *)self.fill;
        NSString *uniqueID = [[WDSVGHelper sharedSVGHelper] uniqueIDWithPrefix:(gradient.type == kWDRadialGradient ? @"RadialGradient" : @"LinearGradient")];
        
        WDFillTransform *fillTransform = [self.fillTransform transform:CGAffineTransformInvert(self.transform)];
        [[WDSVGHelper sharedSVGHelper] addDefinition:[gradient SVGElementWithID:uniqueID fillTransform:fillTransform]];
        
        [element setAttribute:@"fill" value:[NSString stringWithFormat:@"url(#%@)", uniqueID]];
    } else {
        [super addSVGFillAttributes:element];
    }
}

- (void) appendTextSVG:(WDXMLElement *)text
{
    /* generate the path for the text */
    CGMutablePathRef path = CGPathCreateMutable();
    CGRect bounds = self.naturalBounds;
    CGPathAddRect(path, NULL, bounds);
    
    /* draw the text */
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef) self.attributedString);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFRelease(framesetter);
    CFRelease(path);
    
    NSArray *lines = (NSArray *) CTFrameGetLines(frame);
    CGPoint origins[lines.count];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, lines.count), origins);
    
    for (int i = 0; i < lines.count; i++) {
        CTLineRef lineRef = (__bridge CTLineRef) lines[i]; 
        CGFloat lineWidth = CTLineGetTypographicBounds(lineRef, NULL, NULL, NULL);
        
        CFRange range = CTLineGetStringRange(lineRef);
        NSString *substring = [[text_ substringWithRange:NSMakeRange(range.location, range.length)] stringByEscapingEntities];
        
        WDXMLElement *tspan = [WDXMLElement elementWithName:@"tspan"];
        switch (alignment_) {
            case NSTextAlignmentLeft:
                [tspan setAttribute:@"x" floatValue:origins[i].x];
                break;
            case NSTextAlignmentCenter:
                [tspan setAttribute:@"x" floatValue:origins[i].x + lineWidth / 2.f];
                break;
            case NSTextAlignmentRight:
                [tspan setAttribute:@"x" floatValue:origins[i].x + lineWidth];
                break;
            default:
                [tspan setAttribute:@"x" floatValue:origins[i].x];
                break;
                
        }
        [tspan setAttribute:@"y" floatValue:CGRectGetHeight(bounds) - origins[i].y];
        [tspan setAttribute:@"textLength" floatValue:lineWidth];
        [tspan setValue:substring];
        [text addChild:tspan];
    }
    
    CFRelease(frame);
}

- (WDXMLElement *) SVGElement
{
    WDXMLElement *text = [WDXMLElement elementWithName:@"text"];
    [self appendTextSVG:text];
    
    [self addSVGFillAndStrokeAttributes:text];
    [self addSVGOpacityAndShadowAttributes:text];                
    [text setAttribute:@"transform" value:WDSVGStringForCGAffineTransform(transform_)];
    [text setAttribute:@"font-family" value:[NSString stringWithFormat:@"'%@'", fontName_]];
    [text setAttribute:@"font-size" floatValue:fontSize_];
    switch (alignment_) {
        case NSTextAlignmentLeft:
            [text setAttribute:@"text-anchor" value:@"start"];
            break;
        case NSTextAlignmentCenter:
            [text setAttribute:@"text-anchor" value:@"middle"];
            break;
        case NSTextAlignmentRight:
            [text setAttribute:@"text-anchor" value:@"end"];
            break;
        default:
            [text setAttribute:@"text-anchor" value:@"start"];
            break;
    }
    [text setAttribute:@"x" floatValue:self.naturalBounds.origin.x];
    [text setAttribute:@"y" floatValue:self.naturalBounds.origin.y];
    [text setAttribute:@"inkpad:width" floatValue:naturalBounds_.size.width];
    [text setAttribute:@"inkpad:text" value:[self.text stringByEscapingEntitiesAndWhitespace]];
    
    if (self.maskedElements && [self.maskedElements count] > 0) {
        // Produces an element such as:
        // <defs>
        //   <text id="TextN"><tspan>...</tspan></text>
        // </defs>
        // <g opacity="..." inkpad:shadowColor="..." inkpad:mask="#TextN">
        //   <use xlink:href="#TextN" fill="..."/>
        //   <clipPath id="ClipPathN">
        //     <use xlink:href="#TextN" overflow="visible"/>
        //   </clipPath>
        //   <g clip-path="url(#ClipPathN)">
        //     <!-- clipped elements -->
        //   </g>
        //   <use xlink:href="#TextN" stroke="..."/>
        // </g>
        NSString        *uniqueMask = [[WDSVGHelper sharedSVGHelper] uniqueIDWithPrefix:@"Text"];
        NSString        *uniqueClip = [[WDSVGHelper sharedSVGHelper] uniqueIDWithPrefix:@"ClipPath"];
        
        [text setAttribute:@"id" value:uniqueMask];
        [[WDSVGHelper sharedSVGHelper] addDefinition:text];
        
        WDXMLElement *group = [WDXMLElement elementWithName:@"g"];
        [group setAttribute:@"inkpad:mask" value:[NSString stringWithFormat:@"#%@", uniqueMask]];
        [self addSVGOpacityAndShadowAttributes:group];
        
        if (self.fill) {
            // add a path for the fill
            WDXMLElement *use = [WDXMLElement elementWithName:@"use"];
            [use setAttribute:@"xlink:href" value:[NSString stringWithFormat:@"#%@", uniqueMask]];
            [self addSVGFillAttributes:use];
            [group addChild:use];
        }
        
        WDXMLElement *clipPath = [WDXMLElement elementWithName:@"clipPath"];
        [clipPath setAttribute:@"id" value:uniqueClip];
        
        WDXMLElement *use = [WDXMLElement elementWithName:@"use"];
        [use setAttribute:@"xlink:href" value:[NSString stringWithFormat:@"#%@", uniqueMask]];
        [use setAttribute:@"overflow" value:@"visible"];
        [clipPath addChild:use];
        [group addChild:clipPath];
        
        WDXMLElement *elements = [WDXMLElement elementWithName:@"g"];
        [elements setAttribute:@"clip-path" value:[NSString stringWithFormat:@"url(#%@)", uniqueClip]];
        
        for (WDElement *element in self.maskedElements) {
            [elements addChild:[element SVGElement]];
        }
        [group addChild:elements];
        
        if (self.strokeStyle) {
            // add a path for the stroke
            WDXMLElement *use = [WDXMLElement elementWithName:@"use"];
            [use setAttribute:@"xlink:href" value:[NSString stringWithFormat:@"#%@", uniqueMask]];
            [use setAttribute:@"fill" value:@"none"];
            [self.strokeStyle addSVGAttributes:use];
            [group addChild:use];
        }
        
        return group;
    } else {
        return text;
    }
}

- (NSArray *) outlines
{
    NSMutableArray *paths = [NSMutableArray array];
    
    [self layout];
    
    for (id pathRef in glyphs_) {
        CGPathRef glyphPath = (__bridge CGPathRef) pathRef;
        [paths addObject:[WDAbstractPath pathWithCGPathRef:glyphPath]];
    }
    
    return paths;
}

- (void) drawOpenGLTextOutlinesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    [self.layer.highlightColor openGLSet];
    
    CGAffineTransform glTransform = CGAffineTransformConcat(transform, viewTransform);
    
    [self layout];
    
    for (id pathRef in glyphs_) {
        CGPathRef glyphPath = (__bridge CGPathRef) pathRef;
        
        CGPathRef transformed = WDCreateTransformedCGPathRef(glyphPath, glTransform);
        WDGLRenderCGPathRef(transformed);
        CGPathRelease(transformed);
    }
}

- (id) copyWithZone:(NSZone *)zone
{
    WDText *text = [super copyWithZone:zone];
    
    text->width_ = width_;
    text->transform_ = transform_;
    text->alignment_ = alignment_;
    text->text_ = [text_ copy];
    text->fontName_ = [fontName_ copy];
    text->fontSize_ = fontSize_;
    
    text->needsLayout_ = YES;
    text->naturalBoundsDirty_ = YES;
    
    return text;
}

@end

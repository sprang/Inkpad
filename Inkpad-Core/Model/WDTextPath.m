//
//  WDTextPath.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#if !TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import "NSCoderAdditions.h"
#endif

#import <CoreText/CoreText.h>
#import "NSString+Additions.h"
#import "UIColor+Additions.h"
#import "WDBezierNode.h"
#import "WDBezierSegment.h"
#import "WDColor.h"
#import "WDFillTransform.h"
#import "WDFontManager.h"
#import "WDGLUtilities.h"
#import "WDGradient.h"
#import "WDInspectableProperties.h"
#import "WDLayer.h"
#import "WDSVGHelper.h"
#import "WDTextPath.h"
#import "WDUtilities.h"

NSString *WDTextPathMethodKey = @"WDTextPathMethodKey";
NSString *WDTextPathOrientationKey = @"WDTextPathOrientationKey";
NSString *WDTextPathStartOffsetKey = @"WDTextPathStartOffsetKey";
NSString *WDTextPathAlignmentKey = @"WDTextPathAlignmentKey";

#define kOverflowRadius             4
#define kStartBarLength             30
#define kMaxOutwardKernAdjustment   (-0.25f)

@interface WDTextPath (WDPrivate)
- (NSInteger) segmentCount;
- (void) layout;
- (void) getStartKnobBase:(CGPoint *)base andTop:(CGPoint *)top;
@end

@implementation WDTextPath

@synthesize text = text_;
@synthesize fontName = fontName_;
@synthesize fontSize = fontSize_;
@synthesize alignment = alignment_;
@synthesize startOffset = startOffset_;
@synthesize attributedString = attributedString_;
@synthesize cachedStartOffset = cachedStartOffset_;

+ (WDTextPath *) textPathWithPath:(WDPath *)path
{
    WDTextPath *typePath = [[WDTextPath alloc] init];

    NSMutableArray *nodes = [path.nodes copy];
    typePath.nodes = nodes;
    
    typePath.reversed = path.reversed;
    typePath.closed = path.closed;
    
    return typePath;
}

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    transform_ = CGAffineTransformIdentity;
    
    return self;
}

- (void) dealloc
{
    if (fontRef_) {
        CFRelease(fontRef_);
    }
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeObject:text_ forKey:WDTextKey];
    [coder encodeObject:fontName_ forKey:WDFontNameKey];
    [coder encodeFloat:fontSize_ forKey:WDFontSizeKey];
    [coder encodeInt32:alignment_ forKey:WDTextPathAlignmentKey];
    [coder encodeFloat:startOffset_ forKey:WDTextPathStartOffsetKey];
    [coder encodeCGAffineTransform:transform_ forKey:WDTransformKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    text_ = [coder decodeObjectForKey:WDTextKey];
    startOffset_ = [coder decodeFloatForKey:WDTextPathStartOffsetKey]; 
    
    if ([coder containsValueForKey:WDTextPathAlignmentKey]) {
        alignment_ = [coder decodeInt32ForKey:WDTextPathAlignmentKey];
    }
    
    fontName_ = [coder decodeObjectForKey:WDFontNameKey];
    fontSize_ = [coder decodeFloatForKey:WDFontSizeKey];
    transform_ = [coder decodeCGAffineTransformForKey:WDTransformKey];
    
    if (![[WDFontManager sharedInstance] validFont:fontName_]) {
        fontName_ = @"Helvetica";
    }
    
    needsLayout_ = YES;
    
    return self; 
}

- (CGRect) styleBounds 
{
    [self layout];
    return [self expandStyleBounds:styleBounds_];
}

- (BOOL) hasEditableText
{
    return YES;
}

- (BOOL) hasFill
{
    return NO; // only the text has a fill, not the path itself
}

- (BOOL) canPlaceText
{
    return NO;
}

- (NSSet *) inspectableProperties
{
    static NSMutableSet *inspectableProperties = nil;
    
    if (!inspectableProperties) {
        inspectableProperties = [NSMutableSet setWithObjects:WDFontNameProperty, WDFontSizeProperty, nil];
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
    } else {
        return [super valueForProperty:property];
    }
    
    return nil;
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

- (CTFontRef) fontRef
{
    if (!fontRef_) {
        fontRef_ = [[WDFontManager sharedInstance] newFontRefForFont:fontName_ withSize:fontSize_ provideDefault:YES];
    }
    
    return fontRef_;
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
    
    BOOL first = YES;
    NSArray *substrings = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *stripped = @"";
    for (NSString *sub in substrings) {
        if (!first) {
            stripped = [stripped stringByAppendingString:@" "];
        } else {
            first =  NO;
        }
        stripped = [stripped stringByAppendingString:sub];
    }
    text = stripped;
    
    text_ = text;
    attributedString_ = nil;
    needsLayout_ = YES;
    
    [self postDirtyBoundsChange];
}

- (void) setFontName:(NSString *)fontName
{
    [self cacheDirtyBounds];
    
    [[self.undoManager prepareWithInvocationTarget:self] setFontName:fontName_];
    
    fontName_ = fontName;
    
    if (fontRef_) {
        CFRelease(fontRef_);
        fontRef_ = NULL;
    }
    
    CGPathRelease(pathRef_);
    pathRef_ = NULL;
    
    attributedString_ = nil;
    
    needsLayout_ = YES;
    
    [self postDirtyBoundsChange];
    
    [self propertiesChanged:[NSSet setWithObjects:WDFontNameProperty, nil]];
}

- (void) setFontSize:(float)size
{
    [self cacheDirtyBounds];
    
    [(WDTextPath *)[self.undoManager prepareWithInvocationTarget:self] setFontSize:fontSize_];
    
    fontSize_ = size;
    
    if (fontRef_) {
        CFRelease(fontRef_);
        fontRef_ = NULL;
    }
    
    CGPathRelease(pathRef_);
    pathRef_ = NULL;
    
    attributedString_ = nil;
    needsLayout_ = YES;
    
    [self postDirtyBoundsChange];
    
    [self propertiesChanged:[NSSet setWithObjects:WDFontSizeProperty, nil]];
}

- (void) setAlignment:(WDTextPathAlignment)alignment
{
    [self cacheDirtyBounds];
    
    [(WDTextPath *)[self.undoManager prepareWithInvocationTarget:self] setAlignment:alignment_];
    
    alignment_ = alignment;
    needsLayout_ = YES;
    
    [self postDirtyBoundsChange];
}

- (NSAttributedString *) attributedString
{
    if (!text_ || !fontName_) {
        return nil;
    }
    
    if (!attributedString_) {
        CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
        
        CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), (CFStringRef)text_);
        CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength((CFStringRef)text_)), kCTFontAttributeName, [self fontRef]);
        
        // paint with the foreground color
        CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength((CFStringRef)text_)), kCTForegroundColorFromContextAttributeName, kCFBooleanTrue);
        CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength((CFStringRef)text_)), kCTLigatureAttributeName, kCFBooleanFalse);
    
        attributedString_ = (NSAttributedString *) CFBridgingRelease(attrString);
    }
    
    return attributedString_;
}

- (CGPoint) getPointOnPathAtDistance:(float)distance tangentVector:(CGPoint *)tangent transformed:(BOOL)transformed
{
    NSArray             *nodes = reversed_ ? [self reversedNodes] : nodes_;
    NSInteger           numNodes = closed_ ? (nodes.count + 1) : nodes.count;
    WDBezierSegment     segment;
    WDBezierNode        *prev, *curr;
    float               length = 0;
    CGAffineTransform   inverse = transformed ? CGAffineTransformInvert(transform_) : CGAffineTransformIdentity;
    
    prev = [nodes[0] transform:inverse];
    for (int i = 1; i < numNodes; i++) {
        curr = [nodes[(i % nodes.count)] transform:inverse];
        
        segment = WDBezierSegmentMake(prev, curr);
        length = WDBezierSegmentLength(segment);
        
        if (distance < length) {
            // this is our segment, baby
            return WDBezierSegmentPointAndTangentAtDistance(segment, distance, tangent, NULL);
        }
                                                                      
        distance -= length;
        prev = curr;
    }
    
    return CGPointZero;
}

- (void) invalidatePath
{
    [super invalidatePath];
    needsLayout_ = YES;
}

- (float) getSegments:(WDBezierSegment *)segments andLengths:(float *)lengths naturalSpace:(BOOL)transform
{
    NSArray             *nodes = reversed_ ? [self reversedNodes] : nodes_;
    NSInteger           numNodes = closed_ ? (nodes.count + 1) : nodes.count;
    WDBezierNode        *prev, *curr;
    CGAffineTransform   inverse = transform ? CGAffineTransformInvert(transform_) : CGAffineTransformIdentity;
    float               totalLength = 0.0f;
    
    prev = [nodes[0] transform:inverse];
    for (int i = 1; i < numNodes; i++) {
        curr = [nodes[(i % nodes.count)] transform:inverse];
        
        segments[i-1] = WDBezierSegmentMake(prev, curr);
        lengths[i-1] = WDBezierSegmentLength(segments[i-1]);
        totalLength += lengths[i-1];

        prev = curr;
    }
    
    return totalLength;
}

- (float) length:(BOOL)naturalSpace
{
    NSInteger           numSegments = [self segmentCount];
    WDBezierSegment     segments[numSegments];
    float               lengths[numSegments];
    
    // precalculate the segments and their arc lengths
    return [self getSegments:segments andLengths:lengths naturalSpace:naturalSpace];
}

- (BOOL) cornerAtEndOfSegment:(int)ix segments:(WDBezierSegment *)segments count:(NSInteger)numSegments
{
    if (!closed_ && (ix < 0 || ix >= numSegments)) {
        return NO;
    }
    
    return WDBezierSegmentsFormCorner(segments[ix % numSegments], segments[(ix+1) % numSegments]);
}

- (NSInteger) segmentCount
{
    return (closed_ ? nodes_.count : (nodes_.count - 1));
}

- (void) layout
{
    if (!needsLayout_) {
        return;
    }
    
    // compute glyph positions and angles and determine style bounds
    if (!glyphs_) {
        glyphs_ = [[NSMutableArray alloc] init];
    }
    [glyphs_ removeAllObjects];
    
    styleBounds_ = CGRectNull;
    overflow_ = NO;
    
    // get the attributed string, and bail if it's empty
    CFAttributedStringRef attrString = (__bridge CFAttributedStringRef)self.attributedString;
    if (!attrString) {
        return;
    }
    
    CTLineRef line = CTLineCreateWithAttributedString(attrString);
    
    // see if we have any glyphs to render
    CFIndex glyphCount = CTLineGetGlyphCount(line);
    if (glyphCount == 0) {
        CFRelease(line);
        return;
    }
    
    NSInteger           numSegments = [self segmentCount];
    WDBezierSegment     segments[numSegments];
    float               lengths[numSegments];
    float               totalLength = 0;
    WDQuad              glyphQuad, prevGlyphQuad = WDQuadNull();
    
    // precalculate the segments and their arc lengths
    totalLength = [self getSegments:segments andLengths:lengths naturalSpace:YES];
    
    CFArrayRef  runArray = CTLineGetGlyphRuns(line);
    CFIndex     runCount = CFArrayGetCount(runArray);
    int         currentSegment = 0; // increment this as the distance accumulates
    float       cumulativeSegmentLength = 0;
    float       kern = 0;
    
    // find the segment that contains the start offset
    for (int i = 0; i < numSegments; i++) {
        if (cumulativeSegmentLength + lengths[i] > startOffset_) {
            currentSegment = i;
            break;
        }
        cumulativeSegmentLength += lengths[i];
    }
    
    for (CFIndex runIndex = 0; runIndex < runCount; runIndex++) {
        CTRunRef    run = (CTRunRef)CFArrayGetValueAtIndex(runArray, runIndex);
        CFIndex     runGlyphCount = CTRunGetGlyphCount(run);
        CTFontRef   runFont = CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
        CGGlyph     buffer[glyphCount];
        CGPoint     positions[glyphCount];
        BOOL        avoidPreviousGlyph = NO;
        CGPoint     tangent;
        float       curvature, start, end, midGlyph;
        
        CTRunGetGlyphs(run, CFRangeMake(0, 0), buffer);
        CTRunGetPositions(run, CFRangeMake(0,0), positions);
        
        for (CFIndex runGlyphIndex = 0; runGlyphIndex < runGlyphCount; runGlyphIndex++) {
            CGPathRef baseGlyphPath = CTFontCreatePathForGlyph(runFont, buffer[runGlyphIndex], NULL);
            
            if (!baseGlyphPath) {
                continue;
            } else if (CGPathIsEmpty(baseGlyphPath)) {
                CGPathRelease(baseGlyphPath);
                continue;
            }
            
            CGFloat glyphWidth = CTRunGetTypographicBounds(run, CFRangeMake(runGlyphIndex, 1), NULL, NULL, NULL);
            BOOL fits = NO;
            
            while (!fits) {
                start = startOffset_ + positions[runGlyphIndex].x + kern;
                end = start + glyphWidth;
                midGlyph = (start + end) / 2;
                
                if (end > (totalLength + (closed_ ? startOffset_ : 0))) {
                    // we've run out of room for glyphs
                    overflow_ = YES;
                    CGPathRelease(baseGlyphPath);
                    goto done;
                }
                
                // find the segment where the current mid glyph falls
                while (midGlyph >= (cumulativeSegmentLength + lengths[currentSegment % numSegments])) {
                    // we're advancing to the next segment, see if we've got a corner
                    if ([self cornerAtEndOfSegment:currentSegment segments:segments count:numSegments]) {
                        avoidPreviousGlyph = YES;
                    }
                    
                    cumulativeSegmentLength += lengths[currentSegment % numSegments];
                    currentSegment++;
                }
                
                if (end > (cumulativeSegmentLength + lengths[currentSegment % numSegments]) && [self cornerAtEndOfSegment:currentSegment segments:segments count:numSegments]) {
                    // if the end is overshooting a corner, we need to adjust the kern to move onto the next segment
                    kern = (cumulativeSegmentLength + lengths[currentSegment % numSegments]) - (startOffset_ + positions[runGlyphIndex].x);
                } else {
                    // otherwise, we're good to go
                    fits =  YES;
                }
            }

            CGPoint result = WDBezierSegmentPointAndTangentAtDistance(segments[currentSegment % numSegments], (midGlyph - cumulativeSegmentLength), &tangent, &curvature);
            
            if (curvature > 0) {
                avoidPreviousGlyph = YES;
            } else if (!avoidPreviousGlyph) {
                kern += MAX(curvature * 5, kMaxOutwardKernAdjustment) * glyphWidth;
            }

            CGAffineTransform tX = CGAffineTransformMakeTranslation(result.x, result.y);
            tX = CGAffineTransformScale(tX, 1, -1);
            tX = CGAffineTransformRotate(tX, atan2(-tangent.y, tangent.x));
            tX = CGAffineTransformTranslate(tX, -(glyphWidth / 2), 0);
            tX = CGAffineTransformConcat(tX, transform_);
                  
            CGPathRef glyphPath = WDCreateTransformedCGPathRef(baseGlyphPath, tX);
            glyphQuad = WDQuadWithRect(WDShrinkRect(CGPathGetPathBoundingBox(baseGlyphPath), 0.01f), tX);
                
            if (avoidPreviousGlyph && WDQuadIntersectsQuad(glyphQuad, prevGlyphQuad)) {
                // advance slightly and try to lay out this glyph again
                runGlyphIndex--;
                kern += (glyphWidth / 8); // step by 1/8 glyph width
            } else {
                [glyphs_ addObject:(__bridge id) glyphPath];
                styleBounds_ = CGRectUnion(styleBounds_, WDStrokeBoundsForPath(glyphPath, self.strokeStyle));
                avoidPreviousGlyph = NO;
                prevGlyphQuad = glyphQuad;
            }
                
            CGPathRelease(glyphPath);
            CGPathRelease(baseGlyphPath);
        }
    }
    
done:
    CFRelease(line);
    needsLayout_ = NO;
}

- (void) strokeStyleChanged
{
    needsLayout_ = YES;
}

- (CGAffineTransform) transform
{
    return transform_;
}

- (void) setTransform:(CGAffineTransform)transform
{
    [self cacheDirtyBounds];
    
    [(WDTextPath *)[self.undoManager prepareWithInvocationTarget:self] setTransform:transform_];
    
    transform_ = transform;
    [self invalidatePath];
    
    [self postDirtyBoundsChange];
}

- (void) setStartOffset:(float)offset
{
    [self cacheDirtyBounds];
    
    if (!self.cachedStartOffset) {
        [[self.undoManager prepareWithInvocationTarget:self] setStartOffset:startOffset_];
    }
    
    startOffset_ = offset;
    needsLayout_ = YES;
    
    [self postDirtyBoundsChange];
}

- (NSSet *) transform:(CGAffineTransform)transform
{
    BOOL anyWereSelected = [self anyNodesSelected];
    
    NSSet *changedNodes = [super transform:transform];
    
    if (!anyWereSelected) {
        self.transform = CGAffineTransformConcat(transform_, transform);
    }
    
    return changedNodes;
}

- (void) resetTransform
{
    self.transform = CGAffineTransformIdentity;
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
            BOOL didClip;
            
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

- (void) drawOpenGLHandlesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    [super drawOpenGLHandlesWithTransform:transform viewTransform:viewTransform];

    if (!overflow_ || !CGAffineTransformIsIdentity(transform) || self.displayNodes) {
        return;
    }
    
    CGPoint     overflowPoint;
    CGRect      overflowRect;
    BOOL        selected = NO;
    UIColor     *color = displayColor_ ? displayColor_ : self.layer.highlightColor;
    
    if (!closed_) {
        NSArray *nodes = reversed_ ? [self reversedNodes] : nodes_;
        WDBezierNode *lastNode = [nodes lastObject];
        overflowPoint = CGPointApplyAffineTransform(lastNode.anchorPoint, viewTransform);
        selected = lastNode.selected;
    } else {
        CGPoint tangent;
        CGPoint startBarAttachment = [self getPointOnPathAtDistance:startOffset_ tangentVector:&tangent transformed:YES];
        
        overflowPoint = CGPointApplyAffineTransform(startBarAttachment, CGAffineTransformConcat(transform_, viewTransform));
    }
    
    overflowRect = CGRectMake(overflowPoint.x - kOverflowRadius, overflowPoint.y - kOverflowRadius,
                                     kOverflowRadius * 2, kOverflowRadius * 2);
    if (selected) {
        [color openGLSet];
        WDGLFillRect(overflowRect);
        glColor4f(1, 1, 1, 1);
        WDGLStrokeRect(overflowRect);
    } else {
        glColor4f(1, 1, 1, 1);
        WDGLFillRect(overflowRect);
        [color openGLSet];
        WDGLStrokeRect(overflowRect);
    }
    
    // draw +
    overflowPoint = WDRoundPoint(overflowPoint);
    float fudge = ([UIScreen mainScreen].scale == 1.0) ? 2.0f : 2.5f;

    WDGLLineFromPointToPoint(CGPointMake(overflowPoint.x - 3, overflowPoint.y),
                             CGPointMake(overflowPoint.x + fudge, overflowPoint.y));
    
    WDGLLineFromPointToPoint(CGPointMake(overflowPoint.x, overflowPoint.y - fudge),
                             CGPointMake(overflowPoint.x, overflowPoint.y + 3));
}

- (void) drawTextPathControlsWithViewTransform:(CGAffineTransform)viewTransform
{
    // draw start bar
    CGPoint     base, top;
    UIColor     *color = displayColor_ ? displayColor_ : self.layer.highlightColor;
    
    [self getStartKnobBase:&base andTop:&top];
    
    base = CGPointApplyAffineTransform(base, viewTransform);
    base = WDRoundPoint(base);
    
    top = CGPointApplyAffineTransform(top, viewTransform);
    top = WDRoundPoint(top);
    
    [color openGLSet];
    WDGLLineFromPointToPoint(base, top);
    
    [[UIColor whiteColor] openGLSet];
    WDGLFillCircle(top, 4, 12);
    [color openGLSet];
    WDGLStrokeCircle(top, 4, 12);
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
    [super drawOpenGLHighlightWithTransform:transform viewTransform:viewTransform];
    
    if ((![self anyNodesSelected] && !CGAffineTransformEqualToTransform(transform, CGAffineTransformIdentity)) || cachedStartOffset_) {
        [self drawOpenGLTextOutlinesWithTransform:transform viewTransform:viewTransform];
    }
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

- (BOOL) isErasable
{
    return NO;
}

- (BOOL) canOutlineStroke
{
    return NO;
}

- (void) getStartKnobBase:(CGPoint *)base andTop:(CGPoint *)top
{
    float   startDistance = MIN(startOffset_ + 0.01, [self length:YES] - 0.01); // add some fudge
    CGPoint tangent = CGPointZero;
    CGPoint startPt = [self getPointOnPathAtDistance:startDistance tangentVector:&tangent transformed:YES];
    
    CGPoint endPt = WDNormalizePoint(CGPointMake(tangent.y, -tangent.x));
    endPt = WDMultiplyPointScalar(endPt, kStartBarLength);
    
    // find the distance in user space and scale the end point appropriately
    float userSpaceDistance = WDDistance(CGPointApplyAffineTransform(startPt, transform_), CGPointApplyAffineTransform(WDAddPoints(startPt, endPt), transform_));
    endPt = WDMultiplyPointScalar(endPt, kStartBarLength / userSpaceDistance);
    
    endPt = WDAddPoints(startPt, endPt);
    endPt = WDRoundPoint(endPt);
    
    startPt = CGPointApplyAffineTransform(startPt, transform_);
    endPt = CGPointApplyAffineTransform(endPt, transform_);
    
    *base = startPt;
    *top = endPt;
}

- (CGRect) controlBounds
{
    CGPoint base, top;
    [self getStartKnobBase:&base andTop:&top];
    
    return WDGrowRectToPoint([super controlBounds], top);
}

- (WDPickResult *) hitResultForPoint:(CGPoint)point viewScale:(float)viewScale snapFlags:(int)flags
{
    WDPickResult        *result = [WDPickResult pickResult];
    CGRect              pointRect = WDRectFromPoint(point, kNodeSelectionTolerance / viewScale, kNodeSelectionTolerance / viewScale);
    float               distance;
    float               tolerance = kNodeSelectionTolerance / viewScale;
    
    if (!CGRectIntersectsRect(pointRect, [self controlBounds])) {
        return result;
    }
    
    if (flags & kWDSnapNodes) {
        CGPoint base, top;
        [self getStartKnobBase:&base andTop:&top];
        
        distance = WDDistance(top, point);
        if (distance < tolerance) {
            result.type = kWDTextPathStartKnob;
            result.element = self;
        }
    }
    
    if (result.type == kWDEther) {
        return [super hitResultForPoint:point viewScale:viewScale snapFlags:flags];
    }
    
    return result;
}

- (void) cacheOriginalStartOffset
{
    [self cacheDirtyBounds];
    self.cachedStartOffset = @(startOffset_);
}

- (void) registerUndoWithCachedStartOffset
{   
    if ([self.cachedStartOffset floatValue] == startOffset_) {
        self.cachedStartOffset = nil;
        // make the selection view update
        [self postDirtyBoundsChange];
        return;
    }
    
    [[self.undoManager prepareWithInvocationTarget:self] setStartOffset:[self.cachedStartOffset floatValue]];
    self.cachedStartOffset = nil;
    
    [self postDirtyBoundsChange];
}

- (void) moveStartKnobToNearestPoint:(CGPoint)pt
{
    NSInteger           numSegments = [self segmentCount];
    WDBezierSegment     segments[numSegments];
    float               lengths[numSegments];
    float               lowestError = MAXFLOAT;
    int                 closestSegmentIx = 0;
    float               distanceAlongPath = 0;
    
    CGAffineTransform invert = CGAffineTransformInvert(transform_);
    pt = CGPointApplyAffineTransform(pt, invert);
    
    // precalculate the segments and their arc lengths
    [self getSegments:segments andLengths:lengths naturalSpace:YES];
    
    for (int i = 0; i < numSegments; i++) {
        float   error, distance;
        WDBezierSegmentGetClosestPoint(segments[i], pt, &error, &distance);
        
        if (error < lowestError) {
            lowestError = error;
            closestSegmentIx = i;
            distanceAlongPath = distance;
        }
    }
    
    float sum = distanceAlongPath;
    for (int i = 0; i < closestSegmentIx; i++) {
        sum += lengths[i];
    }
    
    startOffset_ = sum;
    needsLayout_ = YES;
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

- (WDXMLElement *) SVGElement
{
    NSString *uniquePath = [[WDSVGHelper sharedSVGHelper] uniqueIDWithPrefix:@"TextPath"];
    
    WDXMLElement *path = [WDXMLElement elementWithName:@"path"];
    [path setAttribute:@"id" value:uniquePath];
    [path setAttribute:@"d" value:[self nodeSVGRepresentation]];
    [path setAttribute:@"transform" value:WDSVGStringForCGAffineTransform(CGAffineTransformInvert(transform_))];
    [[WDSVGHelper sharedSVGHelper] addDefinition:path];
    
    WDXMLElement *text = [WDXMLElement elementWithName:@"text"];
    [text setAttribute:@"font-family" value:[NSString stringWithFormat:@"'%@'", fontName_]];
    [text setAttribute:@"font-size" floatValue:fontSize_];
    [text setAttribute:@"transform" value:WDSVGStringForCGAffineTransform(transform_)];
    [self addSVGOpacityAndShadowAttributes:text];
    [self addSVGFillAndStrokeAttributes:text];
    
    WDXMLElement *textPath = [WDXMLElement elementWithName:@"textPath"];
    [textPath setAttribute:@"xlink:href" value:[NSString stringWithFormat:@"#%@", uniquePath]];
    [textPath setAttribute:@"startOffset" value:[NSString stringWithFormat:@"%gpt", startOffset_]];
    [textPath setAttribute:@"method" value:@"align"];
    [textPath setValue:[text_ stringByEscapingEntities]];
    [text addChild:textPath];
    
    if (self.maskedElements && [self.maskedElements count] > 0) {
        // Produces an element such as:
        // <defs>
        //   <path id="TextPathN" d="..."/>
        //   <text id="TextN"><textPath xlink:href="#TextPathN">...</textPath></text>
        // </defs>
        // <g opacity="..." inkpad:shadowColor="...">
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
        
        [[WDSVGHelper sharedSVGHelper] addDefinition:path];
        
        WDXMLElement *text = [WDXMLElement elementWithName:@"text"];
        [text setAttribute:@"id" value:uniqueMask];
        
        WDXMLElement *textPath = [WDXMLElement elementWithName:@"textPath"];
        [textPath setAttribute:@"xlink:href" value:[NSString stringWithFormat:@"#%@", uniquePath]];
        [textPath setAttribute:@"startOffset" value:[NSString stringWithFormat:@"%g", startOffset_]];
        [textPath setAttribute:@"method" value:@"align"];
        [textPath setValue:[text_ stringByEscapingEntities]];
        [text addChild:textPath];
        
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

- (id) copyWithZone:(NSZone *)zone
{
    WDTextPath *text = [super copyWithZone:zone];
    
    text->text_ = [text_ copy];
    text->startOffset_ = startOffset_;
    text->alignment_ = alignment_;
    text->transform_ = transform_;
    text->fontName_ = [fontName_ copy];
    text->fontSize_ = fontSize_;
    
    text->needsLayout_ = YES;
    
    return text;
}

@end

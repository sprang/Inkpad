//
//  WDImage.m
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

#import "UIColor+Additions.h"
#import "WDColor.h"
#import "WDGLUtilities.h"
#import "WDImage.h"
#import "WDImageData.h"
#import "WDLayer.h"
#import "WDShadow.h"
#import "WDSVGHelper.h"
#import "WDUtilities.h"

NSString *WDImageDataKey = @"WDImageDataKey";

@implementation WDImage

@synthesize transform = transform_;
@synthesize imageData = imageData_;

+ (WDImage *) imageWithUIImage:(UIImage *)image inDrawing:(WDDrawing *)drawing
{
    return [[WDImage alloc] initWithUIImage:image inDrawing:drawing];
}

- (void) computeCorners
{
    CGRect bounds = [self naturalBounds];
    
    corner_[0] = bounds.origin;
    corner_[1] = CGPointMake(CGRectGetMaxX(bounds), 0);
    corner_[2] = CGPointMake(CGRectGetMaxX(bounds), CGRectGetMaxY(bounds));
    corner_[3] = CGPointMake(0, CGRectGetMaxY(bounds));
}

- (id) initWithUIImage:(UIImage *)image inDrawing:(WDDrawing *)drawing
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    imageData_ = [drawing imageDataForUIImage:image];
    transform_ = CGAffineTransformIdentity;
    
    [self computeCorners];
    
    return self;
}

- (void) dealloc
{
    CGPathRelease(pathRef_);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeCGAffineTransform:transform_ forKey:WDTransformKey];
    [coder encodeObject:imageData_ forKey:WDImageDataKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    transform_ = [coder decodeCGAffineTransformForKey:WDTransformKey];
    imageData_ = [coder decodeObjectForKey:WDImageDataKey];
    
    [self computeCorners];
    
    return self; 
}

- (void) useTrackedImageData
{
    if (self.layer.drawing) {
        // make sure our imagedata is registered with the document and not duplicated
        WDImageData *tracked = [self.layer.drawing trackedImageData:imageData_];
        if (tracked != imageData_) {
            imageData_ = tracked;
        }
    }
}

- (void) awakeFromEncoding
{
    [self useTrackedImageData];
}

- (void) setLayer:(WDLayer *)layer
{
    [super setLayer:layer];
    [self useTrackedImageData];
}

- (CGRect) naturalBounds
{
    CGSize naturalSize = imageData_.image.size;
    return CGRectMake(0, 0, naturalSize.width, naturalSize.height);
}

- (CGRect) bounds
{
    return CGRectApplyAffineTransform(self.naturalBounds, transform_);
}

- (CGMutablePathRef) pathRef
{
    if (!pathRef_) {
        pathRef_ = CGPathCreateMutable();
        CGPathAddRect(pathRef_, &transform_, self.naturalBounds);
    }
    
    return pathRef_;
}

- (BOOL) containsPoint:(CGPoint)pt
{
    return CGPathContainsPoint(self.pathRef, NULL, pt, 0);
}

- (BOOL) intersectsRect:(CGRect)rect
{
    CGPoint     ul, ur, lr, ll;
    
    ul = CGPointZero;
    ur = CGPointMake(CGRectGetWidth(self.naturalBounds), 0);
    lr = CGPointMake(CGRectGetWidth(self.naturalBounds), CGRectGetHeight(self.naturalBounds));
    ll = CGPointMake(0, CGRectGetHeight(self.naturalBounds));
    
    ul = CGPointApplyAffineTransform(ul, transform_);
    ur = CGPointApplyAffineTransform(ur, transform_);
    lr = CGPointApplyAffineTransform(lr, transform_);
    ll = CGPointApplyAffineTransform(ll, transform_);
    
    return (WDLineInRect(ul, ur, rect) ||
            WDLineInRect(ur, lr, rect) ||
            WDLineInRect(lr, ll, rect) ||
            WDLineInRect(ll, ul, rect));
}

- (void) renderInContext:(CGContextRef)ctx metaData:(WDRenderingMetaData)metaData
{
    if (metaData.flags & WDRenderOutlineOnly) {
        CGContextAddPath(ctx, self.pathRef);
        
        // draw an X to mark the spot
        CGPoint corners[4];
        
        corners[0] = corner_[0]; // ul
        corners[1] = corner_[2]; // lr
        corners[2] = corner_[1]; // ur
        corners[3] = corner_[3]; // ll
        
        for (int i = 0; i < 4; i++) {
            corners[i] = CGPointApplyAffineTransform(corners[i], transform_);
        }
        
        CGContextAddLines(ctx, corners, 4);
        CGContextStrokePath(ctx);
    } else {
        CGContextSaveGState(ctx);
        
        if (self.shadow && metaData.scale <= 3) {
            [self.shadow applyInContext:ctx metaData:metaData];
        }
        
        CGContextConcatCTM(ctx, transform_);
        UIGraphicsPushContext(ctx);
        [((metaData.flags & WDRenderThumbnail) ? imageData_.thumbnailImage : imageData_.image) drawInRect:imageData_.naturalBounds
                                                                                                blendMode:self.blendMode
                                                                                                    alpha:self.opacity];
        UIGraphicsPopContext();
        CGContextRestoreGState(ctx);
    }
}

- (void) setTransform:(CGAffineTransform)transform
{
    [self cacheDirtyBounds];
    
    [(WDImage *)[self.undoManager prepareWithInvocationTarget:self] setTransform:transform_];

    transform_ = transform;
    
    CGPathRelease(pathRef_);
    pathRef_ = NULL;
    
    [self postDirtyBoundsChange];
}

- (NSSet *) transform:(CGAffineTransform)transform
{
    self.transform = CGAffineTransformConcat(transform_, transform);
    return nil;
}

- (void) drawOpenGLAnchorsWithViewTransform:(CGAffineTransform)transform
{
    for (int i = 0; i < 4; i++) {
        [self drawOpenGLAnchorAtPoint:CGPointApplyAffineTransform(corner_[i], transform_) transform:transform selected:YES];
    }
}

- (void) drawOpenGLHandlesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    for (int i = 0; i < 4; i++) {
        [self drawOpenGLAnchorAtPoint:CGPointApplyAffineTransform(corner_[i], transform_) transform:viewTransform selected:YES];
    }
}

- (void) drawOpenGLHighlightWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform
{
    CGAffineTransform   tX;
    CGPoint             ul, ur, lr, ll;
    
    tX = CGAffineTransformConcat(transform_, transform);
    tX = CGAffineTransformConcat(tX, viewTransform);
    
    ul = CGPointZero;
    ur = CGPointMake(CGRectGetWidth(self.naturalBounds), 0);
    lr = CGPointMake(CGRectGetWidth(self.naturalBounds), CGRectGetHeight(self.naturalBounds));
    ll = CGPointMake(0, CGRectGetHeight(self.naturalBounds));
    
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
    
    // draw 'X'
    WDGLLineFromPointToPoint(ul, lr);
    WDGLLineFromPointToPoint(ll, ur);
}

- (WDPickResult *) hitResultForPoint:(CGPoint)point viewScale:(float)viewScale snapFlags:(int)flags
{
    WDPickResult        *result = [WDPickResult pickResult];
    CGRect              pointRect = WDRectFromPoint(point, kNodeSelectionTolerance / viewScale, kNodeSelectionTolerance / viewScale);
    
    if (!CGRectIntersectsRect(pointRect, [self bounds])) {
        return result;
    }
    
    if ((flags & kWDSnapNodes) || (flags & kWDSnapEdges)) {
        result = WDSnapToRectangle([self naturalBounds], &transform_, point, viewScale, flags);
        if (result.snapped) {
            result.element = self;
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

- (WDPickResult *) snappedPoint:(CGPoint)point viewScale:(float)viewScale snapFlags:(int)flags
{
    WDPickResult        *result = [WDPickResult pickResult];
    CGRect              pointRect = WDRectFromPoint(point, kNodeSelectionTolerance / viewScale, kNodeSelectionTolerance / viewScale);
    
    if (!CGRectIntersectsRect(pointRect, [self bounds])) {
        return result;
    }
    
    if ((flags & kWDSnapNodes) || (flags & kWDSnapEdges)) {
        result = WDSnapToRectangle([self naturalBounds], &transform_, point, viewScale, flags);
        if (result.snapped) {
            result.element = self;
            return result;
        }
    }
    
    return result;
}

- (id) pathPainterAtPoint:(CGPoint)pt
{
    if (!CGPathContainsPoint(self.pathRef, NULL, pt, true)) {
        return nil;
    }
    
    CGAffineTransform transform = CGAffineTransformInvert(transform_);
    pt = CGPointApplyAffineTransform(pt, transform);
    
    CGImageRef imageRef = imageData_.image.CGImage;
    CGImageRef tinyRef = CGImageCreateWithImageInRect(imageRef, CGRectMake(pt.x, pt.y, 1, 1));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    UInt8 rawData[4] = {255, 255, 255, 255}; // draw over a white background
    CGContextRef context = CGBitmapContextCreate(rawData, 1, 1, 8, 4, colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), tinyRef);
    
    CGContextRelease(context);
    CGImageRelease(tinyRef);
    
    CGFloat red   = rawData[0] / 255.0f;
    CGFloat green = rawData[1] / 255.0f;
    CGFloat blue  = rawData[2] / 255.0f;
    
    return [WDColor colorWithRed:red green:green blue:blue alpha:1.0f];
}

- (WDXMLElement *) SVGElement
{
    NSString *unique = [[WDSVGHelper sharedSVGHelper] imageIDForDigest:imageData_.digest];
    WDXMLElement *image = [WDXMLElement elementWithName:@"use"];
    
    [self addSVGOpacityAndShadowAttributes:image];
    
    [image setAttribute:@"xlink:href" value:[NSString stringWithFormat:@"#%@", unique]];
    [image setAttribute:@"transform" value:WDSVGStringForCGAffineTransform(transform_)];
    
    return image;
}

- (BOOL) needsTransparencyLayer:(float)scale
{
    return NO;
}

- (id) copyWithZone:(NSZone *)zone
{
    WDImage *image = [super copyWithZone:zone];

    image->transform_ = transform_;
    image->imageData_ = [imageData_ copy];
    
    return image;
}
    
@end

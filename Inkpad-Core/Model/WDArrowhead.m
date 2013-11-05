//
//  WDArrowhead.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2013 Steve Sprang
//

#import "WDArrowhead.h"
#import "WDUtilities.h"

@interface WDArrowhead (Private)
+ (NSDictionary *) buildArrows;
@end

@implementation WDArrowhead

@synthesize attachment = attachment_;
@synthesize capAdjustment = capAdjustment_;
@synthesize path = path_;
@synthesize bounds = bounds_;

+ (NSDictionary *) arrowheads
{
    static NSDictionary *arrows = nil;
    
    if (!arrows) {
        arrows = [self buildArrows];
    }
    
    return arrows;
}

+ (WDArrowhead *) arrowheadWithPath:(CGPathRef)pathRef attachment:(CGPoint)attach
{
    return [[WDArrowhead alloc] initWithPath:pathRef attachment:attach capAdjustment:CGPointZero];
}

+ (WDArrowhead *) arrowheadWithPath:(CGPathRef)pathRef attachment:(CGPoint)attach capAdjustment:(CGPoint)adjustment
{
    return [[WDArrowhead alloc] initWithPath:pathRef attachment:attach capAdjustment:adjustment];
}

- (id) initWithPath:(CGPathRef)pathRef attachment:(CGPoint)attach capAdjustment:(CGPoint)adjustment
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    // we want this path to butt up against the origin
    CGRect boundsTest = CGPathGetBoundingBox(pathRef);
    if (!CGPointEqualToPoint(boundsTest.origin, CGPointZero)) {
        CGAffineTransform tX = CGAffineTransformMakeTranslation(-boundsTest.origin.x, -boundsTest.origin.y);
        CGPathRef transformedPath = WDCreateTransformedCGPathRef(pathRef, tX);
        CGPathRelease(pathRef);
        path_ = transformedPath;
        
        // need to shift the attachment point too
        attach = WDAddPoints(attach, WDMultiplyPointScalar(boundsTest.origin, -1));
    } else {
        path_ = pathRef;
    }
    
    attachment_ = attach;
    capAdjustment_ = adjustment;
    
    bounds_ = CGPathGetBoundingBox(path_);
    
    return self;
}

- (void) dealloc
{
    CGPathRelease(path_);
}

- (CGPoint) attachmentAdjusted:(BOOL)adjust
{
    if (adjust) {
        return WDAddPoints(self.attachment, self.capAdjustment);
    } else {
        return self.attachment;
    }
}

- (float) insetLength
{
    return CGRectGetWidth(bounds_) - self.attachment.x;
}

- (float) insetLength:(BOOL)adjusted
{
    return CGRectGetWidth(bounds_) - [self attachmentAdjusted:adjusted].x;
}

- (CGAffineTransform) transformAtPosition:(CGPoint)pt scale:(float)scale angle:(float)angle useAdjustment:(BOOL)adjust
{
    CGPoint attach = [self attachmentAdjusted:adjust];
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, pt.x, pt.y);
    transform = CGAffineTransformScale(transform, scale, scale);
    transform = CGAffineTransformRotate(transform, angle);
    transform = CGAffineTransformTranslate(transform, -attach.x, -attach.y);
    
    return transform;
}

- (CGRect) boundingBoxAtPosition:(CGPoint)pt scale:(float)scale angle:(float)angle useAdjustment:(BOOL)adjust
{
    CGAffineTransform transform = [self transformAtPosition:pt scale:scale angle:angle useAdjustment:adjust];
    CGPathRef rectPath = CGPathCreateWithRect(self.bounds, &transform);
    CGRect arrowBounds = CGPathGetBoundingBox(rectPath);
    CGPathRelease(rectPath);
    
    return arrowBounds;
}

- (void) addToMutablePath:(CGMutablePathRef)pathRef position:(CGPoint)pt scale:(float)scale angle:(float)angle useAdjustment:(BOOL)adjust
{
    CGAffineTransform transform = [self transformAtPosition:pt scale:scale angle:angle useAdjustment:adjust];
    CGPathAddPath(pathRef, &transform, self.path);
}

- (void) addArrowInContext:(CGContextRef)ctx position:(CGPoint)pt scale:(float)scale angle:(float)angle useAdjustment:(BOOL)adjust
{
    CGContextSaveGState(ctx);
    CGContextConcatCTM(ctx, [self transformAtPosition:pt scale:scale angle:angle useAdjustment:adjust]);
    CGContextAddPath(ctx, self.path);
    CGContextRestoreGState(ctx);
}

@end

const float kArrowheadDimension = 7.0f;
const float kHalfArrowheadDimension = kArrowheadDimension / 2;

@implementation WDArrowhead (Private)

+ (NSDictionary *) buildArrows
{
    NSMutableDictionary *arrows = [NSMutableDictionary dictionary];
    CGAffineTransform   flipTransform = CGAffineTransformIdentity;
    CGAffineTransform   diamondTransform = CGAffineTransformIdentity;
    CGMutablePathRef    pathRef;
    CGRect              defaultRect = CGRectMake(0, 0, kArrowheadDimension, kArrowheadDimension);
    
    /*
     * Arrows
     */
    
    pathRef = CGPathCreateMutable();
    CGPathMoveToPoint(pathRef, NULL, (3.0f / 8) * kArrowheadDimension, kHalfArrowheadDimension);
    CGPathAddLineToPoint(pathRef, NULL,  0, kArrowheadDimension);
    CGPathAddLineToPoint(pathRef, NULL, kArrowheadDimension, kHalfArrowheadDimension);
    CGPathAddLineToPoint(pathRef, NULL, 0, 0);
    CGPathCloseSubpath(pathRef);
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake(kHalfArrowheadDimension, kHalfArrowheadDimension)]
               forKey:@"arrow1"];
    
    pathRef = CGPathCreateMutable();
    CGPathMoveToPoint(pathRef, NULL,  0, kArrowheadDimension);
    CGPathAddLineToPoint(pathRef, NULL, kArrowheadDimension - 1, kHalfArrowheadDimension);
    CGPathAddLineToPoint(pathRef, NULL, 0, 0);
    CGPathCloseSubpath(pathRef);
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake(1.5f, kHalfArrowheadDimension)]
               forKey:@"arrow2"];
    
    pathRef = CGPathCreateMutable();
    CGPathMoveToPoint(pathRef, NULL,  kArrowheadDimension / 3 + 0.5f, kArrowheadDimension - 0.5f);
    CGPathAddLineToPoint(pathRef, NULL, kArrowheadDimension - 0.5f, kHalfArrowheadDimension);
    CGPathAddLineToPoint(pathRef, NULL, kArrowheadDimension / 3 + 0.5f, 0.5f);
    CGPathRef outline = CGPathCreateCopyByStrokingPath(pathRef, NULL, 1.0f, kCGLineCapRound, kCGLineJoinMiter, 4);
    CGPathRelease(pathRef);
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:outline attachment:CGPointMake(kArrowheadDimension - 1, kHalfArrowheadDimension)]
               forKey:@"arrow3"];
    
    /*
     * Circles
     */
    
    flipTransform = CGAffineTransformTranslate(flipTransform, 0, kArrowheadDimension);
    flipTransform = CGAffineTransformScale(flipTransform, 1, -1);
    
    pathRef = CGPathCreateMutable();
    CGPathAddEllipseInRect(pathRef, &flipTransform, defaultRect);
    CGPathAddEllipseInRect(pathRef, NULL, CGRectInset(defaultRect, 1, 1));
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef
                                          attachment:CGPointMake(0.25f, kHalfArrowheadDimension)
                                       capAdjustment:CGPointMake(0.25f, 0.0f)]
               forKey:@"open circle"];
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:CGPathCreateWithEllipseInRect(defaultRect, &flipTransform)
                                          attachment:CGPointMake(0.5f, kHalfArrowheadDimension)]
               forKey:@"closed circle"];
    
    /*
     * Squares
     */
    
    pathRef = CGPathCreateMutable();
    CGPathAddRect(pathRef, &flipTransform, CGRectInset(defaultRect, 0.5f, 0.5f));
    CGPathAddRect(pathRef, NULL, CGRectInset(defaultRect, 1.5f, 1.5f));
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef
                                          attachment:CGPointMake(0.75f, kHalfArrowheadDimension)
                                       capAdjustment:CGPointMake(0.25f, 0.0f)]
               forKey:@"open square"];
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:CGPathCreateWithRect(CGRectInset(defaultRect, 0.5f, 0.5f), &flipTransform)
                                          attachment:CGPointMake(1.0f, kHalfArrowheadDimension)]
               forKey:@"closed square"];
    
    /*
     * T Shaped
     */
    
    pathRef = CGPathCreateMutable();
    CGPathAddRect(pathRef, &flipTransform, CGRectMake(0.0f, 0.5f, 1.0f, kArrowheadDimension - 1.0f));
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef
                                          attachment:CGPointMake(0.25f, kHalfArrowheadDimension)
                                       capAdjustment:CGPointMake(0.25f, 0.0f)]
               forKey:@"T shape"];
    
    /*
     * Diamonds
     */
    
    diamondTransform = CGAffineTransformTranslate(diamondTransform, kHalfArrowheadDimension, kHalfArrowheadDimension);
    diamondTransform = CGAffineTransformRotate(diamondTransform, M_PI_4);
    diamondTransform = CGAffineTransformScale(diamondTransform, 1, -1);
    diamondTransform = CGAffineTransformTranslate(diamondTransform, -kHalfArrowheadDimension, -kHalfArrowheadDimension);
    
    CGPathRef diamond = CGPathCreateWithRect(CGRectInset(defaultRect, 1.5f, 1.5f), &diamondTransform);
    outline = CGPathCreateCopyByStrokingPath(diamond, NULL, 1.0f, kCGLineCapButt, kCGLineJoinMiter, 4);
    CGPathRelease(diamond);
    
    CGPoint attach = CGPointApplyAffineTransform(CGPointMake(1.5f, 1.5f), diamondTransform);
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:outline
                                          attachment:attach
                                       capAdjustment:CGPointMake(0.25f, 0.0f)]
               forKey:@"open diamond"];
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:CGPathCreateWithRect(CGRectInset(defaultRect, 1, 1), &diamondTransform)
                                          attachment:CGPointMake(1.0f, kHalfArrowheadDimension)]
               forKey:@"closed diamond"];
    
    return arrows;
}

@end

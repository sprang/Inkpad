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
@synthesize path = path_;
@synthesize bounds = bounds_;
@synthesize insetLength = insetLength_;

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
    return [[WDArrowhead alloc] initWithPath:pathRef attachment:attach];
}

- (id) initWithPath:(CGPathRef)pathRef attachment:(CGPoint)attach
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
    
    bounds_ = CGPathGetBoundingBox(path_);
    insetLength_ = CGRectGetWidth(bounds_) - attachment_.x;
    
    return self;
}

- (CGAffineTransform) transformAtPosition:(CGPoint)pt scale:(float)scale angle:(float)angle
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, pt.x, pt.y);
    transform = CGAffineTransformScale(transform, scale, scale);
    transform = CGAffineTransformRotate(transform, angle);
    transform = CGAffineTransformTranslate(transform, -self.attachment.x, -self.attachment.y);
    
    return transform;
}

- (CGRect) boundingBoxAtPosition:(CGPoint)pt scale:(float)scale angle:(float)angle
{
    CGAffineTransform transform = [self transformAtPosition:pt scale:scale angle:angle];
    CGPathRef rectPath = CGPathCreateWithRect(self.bounds, &transform);
    CGRect arrowBounds = CGPathGetBoundingBox(rectPath);
    CGPathRelease(rectPath);
    
    return arrowBounds;
}

- (void) addToMutablePath:(CGMutablePathRef)pathRef position:(CGPoint)pt scale:(float)scale angle:(float)angle
{
    CGAffineTransform transform = [self transformAtPosition:pt scale:scale angle:angle];
    CGPathAddPath(pathRef, &transform, self.path);
}

- (void) addArrowInContext:(CGContextRef)ctx position:(CGPoint)pt scale:(float)scale angle:(float)angle
{
    CGContextSaveGState(ctx);
    CGContextConcatCTM(ctx, [self transformAtPosition:pt scale:scale angle:angle]);
    CGContextAddPath(ctx, self.path);
    CGContextRestoreGState(ctx);
}

@end

const float kDefaultArrowDimension = 4.0f;

@implementation WDArrowhead (Private)

+ (NSDictionary *) buildArrows
{
    NSMutableDictionary *arrows = [NSMutableDictionary dictionary];
    CGAffineTransform   transform;
    CGMutablePathRef    pathRef;
    CGRect              defaultRect = CGRectMake(0, 0, kDefaultArrowDimension, kDefaultArrowDimension);

    /*
     * Arrows
     */

    pathRef = CGPathCreateMutable();
    float baseArrowDimension = 5.0f;
    CGPathMoveToPoint(pathRef, NULL,  1.5f, baseArrowDimension / 2);
    CGPathAddLineToPoint(pathRef, NULL,  0, baseArrowDimension);
    CGPathAddLineToPoint(pathRef, NULL, baseArrowDimension, baseArrowDimension / 2);
    CGPathAddLineToPoint(pathRef, NULL, 0, 0);
    CGPathCloseSubpath(pathRef);

    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake(1.5, baseArrowDimension / 2)]
               forKey:@"arrow1"];
    
    pathRef = CGPathCreateMutable();
    CGPathMoveToPoint(pathRef, NULL,  0, baseArrowDimension);
    CGPathAddLineToPoint(pathRef, NULL, baseArrowDimension-1, baseArrowDimension / 2);
    CGPathAddLineToPoint(pathRef, NULL, 0, 0);
    CGPathCloseSubpath(pathRef);
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake(1.5, baseArrowDimension / 2)]
               forKey:@"arrow2"];
    
    pathRef = CGPathCreateMutable();
    baseArrowDimension = 4.0f;
    CGPathMoveToPoint(pathRef, NULL,  baseArrowDimension / 3, baseArrowDimension);
    CGPathAddLineToPoint(pathRef, NULL, baseArrowDimension, baseArrowDimension / 2);
    CGPathAddLineToPoint(pathRef, NULL, baseArrowDimension / 3, 0);
    
    CGPathRef outline = CGPathCreateCopyByStrokingPath(pathRef, NULL, 1.0f, kCGLineCapButt, kCGLineJoinMiter, 4);
    CGPathRelease(pathRef);
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:outline attachment:CGPointMake(baseArrowDimension - 0.5, baseArrowDimension / 2)]
               forKey:@"arrow3"];

    /*
     * Circles
     */
    
    transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, 0, kDefaultArrowDimension);
    transform = CGAffineTransformScale(transform, 1, -1);

    pathRef = CGPathCreateMutable();
    CGPathAddEllipseInRect(pathRef, &transform, defaultRect);
    CGPathAddEllipseInRect(pathRef, NULL, CGRectInset(defaultRect, 1, 1));

    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake(0.25, kDefaultArrowDimension / 2)]
               forKey:@"open circle"];
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:CGPathCreateWithEllipseInRect(defaultRect, &transform)
                                          attachment:CGPointMake(0.25, kDefaultArrowDimension / 2)]
               forKey:@"closed circle"];

    /*
     * Squares
     */
    
    pathRef = CGPathCreateMutable();
    CGPathAddRect(pathRef, &transform, defaultRect);
    CGPathAddRect(pathRef, NULL, CGRectInset(defaultRect, 1, 1));

    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake(0.25, kDefaultArrowDimension/2)]
               forKey:@"open square"];

    [arrows setObject:[WDArrowhead arrowheadWithPath:CGPathCreateWithRect(defaultRect, &transform)
                                          attachment:CGPointMake(0.25, kDefaultArrowDimension/2)]
               forKey:@"closed square"];
    
    /*
     * Diamonds
     */
    
    pathRef = CGPathCreateMutable();
    CGPathMoveToPoint(pathRef, NULL, kDefaultArrowDimension / 2, kDefaultArrowDimension);
    CGPathAddLineToPoint(pathRef, NULL, kDefaultArrowDimension, kDefaultArrowDimension / 2);
    CGPathAddLineToPoint(pathRef, NULL, kDefaultArrowDimension / 2, 0);
    CGPathAddLineToPoint(pathRef, NULL,  0, kDefaultArrowDimension / 2);
    CGPathCloseSubpath(pathRef);
    
    outline = CGPathCreateCopyByStrokingPath(pathRef, NULL, 1.0f, kCGLineCapButt, kCGLineJoinMiter, 4);
    CGPathRelease(pathRef);

    [arrows setObject:[WDArrowhead arrowheadWithPath:outline attachment:CGPointMake(0.25, kDefaultArrowDimension/2)]
               forKey:@"open diamond"];
    
    pathRef = CGPathCreateMutable();
    CGPathMoveToPoint(pathRef, NULL, kDefaultArrowDimension / 2, kDefaultArrowDimension);
    CGPathAddLineToPoint(pathRef, NULL, kDefaultArrowDimension, kDefaultArrowDimension / 2);
    CGPathAddLineToPoint(pathRef, NULL, kDefaultArrowDimension / 2, 0);
    CGPathAddLineToPoint(pathRef, NULL,  0, kDefaultArrowDimension / 2);
    CGPathCloseSubpath(pathRef);
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef
                                          attachment:CGPointMake(kDefaultArrowDimension/2, kDefaultArrowDimension/2)]
               forKey:@"closed diamond"];
    
    return arrows;
}

@end

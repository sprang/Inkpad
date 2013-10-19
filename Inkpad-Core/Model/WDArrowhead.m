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

- (void) dealloc
{
    CGPathRelease(path_);
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

const float kArrowheadDimension = 8.0f;
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

    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake((3.0f / 8) * kArrowheadDimension, kHalfArrowheadDimension)]
               forKey:@"arrow1"];
    
    pathRef = CGPathCreateMutable();
    CGPathMoveToPoint(pathRef, NULL,  0, kArrowheadDimension);
    CGPathAddLineToPoint(pathRef, NULL, kArrowheadDimension - 1, kHalfArrowheadDimension);
    CGPathAddLineToPoint(pathRef, NULL, 0, 0);
    CGPathCloseSubpath(pathRef);
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake(1.5, kHalfArrowheadDimension)]
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

    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake(0.25f, kHalfArrowheadDimension)]
               forKey:@"open circle"];
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:CGPathCreateWithEllipseInRect(defaultRect, &flipTransform)
                                          attachment:CGPointMake(0.25f, kHalfArrowheadDimension)]
               forKey:@"closed circle"];

    /*
     * Squares
     */
    
    pathRef = CGPathCreateMutable();
    CGPathAddRect(pathRef, &flipTransform, CGRectInset(defaultRect, 0.5f, 0.5f));
    CGPathAddRect(pathRef, NULL, CGRectInset(defaultRect, 1.5f, 1.5f));

    [arrows setObject:[WDArrowhead arrowheadWithPath:pathRef attachment:CGPointMake(0.75, kHalfArrowheadDimension)]
               forKey:@"open square"];

    [arrows setObject:[WDArrowhead arrowheadWithPath:CGPathCreateWithRect(CGRectInset(defaultRect, 0.5f, 0.5f), &flipTransform)
                                          attachment:CGPointMake(0.75f, kHalfArrowheadDimension)]
               forKey:@"closed square"];
    
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

    [arrows setObject:[WDArrowhead arrowheadWithPath:outline attachment:CGPointMake(0.5f, kHalfArrowheadDimension)]
               forKey:@"open diamond"];
    
    [arrows setObject:[WDArrowhead arrowheadWithPath:CGPathCreateWithRect(CGRectInset(defaultRect, 1, 1), &diamondTransform)
                                          attachment:CGPointMake(0.5f, kHalfArrowheadDimension)]
               forKey:@"closed diamond"];
    
    return arrows;
}

@end

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
    
    path_ = pathRef;
    attachment_ = attach;
    
    bounds_ = CGPathGetBoundingBox(path_);
    insetLength_ = CGRectGetWidth(bounds_) - attachment_.x;
    
    return self;
}

- (CGRect) boundingBoxAtPosition:(CGPoint)pt scale:(float)scale angle:(float)angle
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, pt.x, pt.y);
    transform = CGAffineTransformScale(transform, scale, scale);
    transform = CGAffineTransformRotate(transform, angle);
    transform = CGAffineTransformTranslate(transform, -self.attachment.x, -self.attachment.y);
    
    CGPathRef rectPath = CGPathCreateWithRect(self.bounds, &transform);
    CGRect arrowBounds = CGPathGetBoundingBox(rectPath);
    CGPathRelease(rectPath);
    
    return arrowBounds;
}

- (void) addArrowInContext:(CGContextRef)ctx position:(CGPoint)pt scale:(float)scale angle:(float)angle
{
    CGContextSaveGState(ctx);
    
    CGContextTranslateCTM(ctx, pt.x, pt.y);
    CGContextScaleCTM(ctx, scale, scale);
    CGContextRotateCTM(ctx, angle);
    CGContextTranslateCTM(ctx, -self.attachment.x, -self.attachment.y);
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

    return arrows;
}

@end

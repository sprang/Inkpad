//
//  WDFillTransform.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#if !TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import "NSCoderAdditions.h"
#endif

#import "WDFillTransform.h"

NSString *WDFillTransformStartKey = @"WDFillTransformStartKey";
NSString *WDFillTransformEndKey = @"WDFillTransformEndKey";
NSString *WDFillTransformTransformKey = @"WDFillTransformTransformKey";

@implementation WDFillTransform

@synthesize start = start_;
@synthesize end = end_;
@synthesize transform = transform_;

+ (WDFillTransform *) fillTransformWithRect:(CGRect)rect centered:(BOOL)centered
{
    float   startX = centered ? CGRectGetMidX(rect) : CGRectGetMinX(rect);
    CGPoint start = CGPointMake(startX, CGRectGetMidY(rect));
    CGPoint end = CGPointMake(CGRectGetMaxX(rect), CGRectGetMidY(rect));
    
    WDFillTransform *fT = [[WDFillTransform alloc] initWithTransform:CGAffineTransformIdentity start:start end:end];

    return fT;
}

- (id) initWithTransform:(CGAffineTransform)transform start:(CGPoint)start end:(CGPoint)end
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    transform_ = transform;
    start_ = start;
    end_ = end;
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeCGPoint:start_ forKey:WDFillTransformStartKey];
    [coder encodeCGPoint:end_ forKey:WDFillTransformEndKey];
    [coder encodeCGAffineTransform:transform_ forKey:WDFillTransformTransformKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    start_ = [coder decodeCGPointForKey:WDFillTransformStartKey];
    end_ = [coder decodeCGPointForKey:WDFillTransformEndKey];
    transform_ = [coder decodeCGAffineTransformForKey:WDFillTransformTransformKey];

    return self; 
}

- (BOOL) isDefaultInRect:(CGRect)rect centered:(BOOL)centered
{
    return [self isEqual:[WDFillTransform fillTransformWithRect:rect centered:centered]];
}

- (BOOL) isEqual:(WDFillTransform *)fillTransform
{
    if (fillTransform == self) {
        return YES;
    }
    
    if (!fillTransform || ![fillTransform isKindOfClass:[WDFillTransform class]]) {
        return NO;
    }
    
    return (CGPointEqualToPoint(start_, fillTransform.start) &&
            CGPointEqualToPoint(end_, fillTransform.end) &&
            CGAffineTransformEqualToTransform(self.transform, fillTransform.transform));
}

- (WDFillTransform *) transform:(CGAffineTransform)transform
{
    CGAffineTransform modified = CGAffineTransformConcat(transform_, transform);
    WDFillTransform *new = [[WDFillTransform alloc] initWithTransform:modified start:start_ end:end_];
    return new;
}

- (WDFillTransform *) transformWithTransformedStart:(CGPoint)start
{   
    CGAffineTransform inverted = CGAffineTransformInvert(transform_);
    start = CGPointApplyAffineTransform(start, inverted);
    
    WDFillTransform *new = [[WDFillTransform alloc] initWithTransform:transform_ start:start end:end_];
    return new;
}

- (WDFillTransform *) transformWithTransformedEnd:(CGPoint)end
{   
    CGAffineTransform inverted = CGAffineTransformInvert(transform_);
    end = CGPointApplyAffineTransform(end, inverted);
    
    WDFillTransform *new = [[WDFillTransform alloc] initWithTransform:transform_ start:start_ end:end];
    return new;
}

- (CGPoint) transformedStart
{
    return CGPointApplyAffineTransform(start_, transform_);
}

- (CGPoint) transformedEnd
{
    return CGPointApplyAffineTransform(end_, transform_);
}

- (id) copyWithZone:(NSZone *)zone
{
    return self;
}

@end

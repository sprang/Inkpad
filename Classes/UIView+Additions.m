//
//  UIViewAdditions.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "UIView+Additions.h"
#import "WDUtilities.h"

const float kDefaultParallaxIntensity = 15.0f;

@implementation UIView (Additions)

- (void) setSharpCenter:(CGPoint)center
{
    CGRect frame = self.frame;
    
    frame.origin = WDSubtractPoints(center, CGPointMake(CGRectGetWidth(frame) / 2, CGRectGetHeight(frame) / 2));
    frame.origin = WDRoundPoint(frame.origin);
                              
    self.center = WDCenterOfRect(frame);
}

- (CGPoint) sharpCenter
{
    return self.center;
}

- (UIImage *) imageForView
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    [self.layer renderInContext:ctx];
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

//
// adapted from https://github.com/michaeljbishop/NGAParallaxMotion
//
-(void) addParallaxEffect
{
    float parallaxDepth = kDefaultParallaxIntensity;
    
    UIMotionEffectGroup * parallaxGroup = [[UIMotionEffectGroup alloc] init];
    
    UIInterpolatingMotionEffect *xAxis, *yAxis;
    
    xAxis = [[UIInterpolatingMotionEffect alloc]
             initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    
    yAxis = [[UIInterpolatingMotionEffect alloc]
             initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    
    NSArray *motionEffects = @[xAxis, yAxis];
    for (UIInterpolatingMotionEffect *motionEffect in motionEffects) {
        motionEffect.maximumRelativeValue = @(parallaxDepth);
        motionEffect.minimumRelativeValue = @(-parallaxDepth);
    }
    parallaxGroup.motionEffects = motionEffects;
    
    // clear any old effects
    for (UIMotionEffect *effect in self.motionEffects) {
        [self removeMotionEffect:effect];
    }
    
    [self addMotionEffect:parallaxGroup];
}

@end

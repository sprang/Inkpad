//
//  WDBlockingView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDBlockingView.h"
#import "WDUtilities.h"

@implementation WDBlockingView

@synthesize passthroughViews = passthroughViews_;
@synthesize action = action_;
@synthesize target = target_;

- (UIView *) hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    point = [self convertPoint:point toView:nil];
    
    for (UIView *view in passthroughViews_) {
        CGPoint testPt = [view convertPoint:point fromView:nil];
        if ([view hitTest:testPt withEvent:event]) {
            return nil;
        }
    }
    
    return [super hitTest:point withEvent:event];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    sendAction_ = YES;
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (sendAction_) {
        [[UIApplication sharedApplication] sendAction:action_ to:target_ from:self forEvent:event];
    }
}

- (void) setShadowCenter:(CGPoint)center radius:(float)radius
{
    CALayer *layer = self.layer;
    
    layer.shadowOpacity = 0.5;
    layer.shadowRadius = 25;
    layer.shadowOffset = CGSizeMake(0, 0);
    
    CGPoint rectCenter = WDCenterOfRect(self.bounds);
    // flip one of the paths so that we get a hole in the shadow
    CGAffineTransform tX = CGAffineTransformMakeTranslation(rectCenter.x, rectCenter.y);
    tX = CGAffineTransformScale(tX, 1, -1);
    const CGAffineTransform flip = CGAffineTransformTranslate(tX, -rectCenter.x, -rectCenter.y);
    
    CGMutablePathRef pathRef = CGPathCreateMutable();
    CGPathAddRect(pathRef, &flip, CGRectInset(self.bounds, -50, -50));
    CGPathAddEllipseInRect(pathRef, NULL, CGRectMake(center.x - radius, center.y - radius, radius * 2, radius * 2));
    
    layer.shadowPath = pathRef;
    CGPathRelease(pathRef);
}

@end

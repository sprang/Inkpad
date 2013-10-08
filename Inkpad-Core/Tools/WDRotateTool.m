//
//  WDRotateTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDRotateTool.h"
#import "WDUtilities.h"

@implementation WDRotateTool

- (NSString *) iconName
{
    return @"rotate.png";
}

- (CGAffineTransform) computeTransform:(CGPoint)pt pivot:(CGPoint)pivot constrain:(WDToolFlags)flags
{
    CGPoint delta = WDSubtractPoints(self.initialEvent.location, pivot);
    double offsetAngle = atan2(delta.y, delta.x);

    delta = WDSubtractPoints(pt, pivot);
    double angle = atan2(delta.y, delta.x);
    double diff = angle - offsetAngle;
    
    if ((flags & WDToolShiftKey) || (flags & WDToolSecondaryTouch)) {
        float degrees = diff * 180 / M_PI;
        degrees = round(degrees / 45) * 45;
        diff = degrees * M_PI / 180.0f;
    }

    CGAffineTransform transform = CGAffineTransformMakeTranslation(pivot.x, pivot.y);
    transform = CGAffineTransformRotate(transform, diff);
    transform = CGAffineTransformTranslate(transform, -pivot.x, -pivot.y);
    
    return transform;
}

@end

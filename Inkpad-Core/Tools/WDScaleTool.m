//
//  WDScaleTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDScaleTool.h"
#import "WDUtilities.h"

#define INVERTED_CONSTRAIN YES

@implementation WDScaleTool

- (NSString *) iconName
{
    return @"scale.png";
}

- (CGAffineTransform) computeTransform:(CGPoint)pt pivot:(CGPoint)pivot constrain:(WDToolFlags)flags
{
    CGPoint delta = WDSubtractPoints(self.initialEvent.location, pivot);
    CGPoint newDelta = WDSubtractPoints(pt, pivot);
    float   scaleX = 1, scaleY = 1;
    BOOL    constrain = ((flags & WDToolShiftKey) || (flags & WDToolSecondaryTouch)) ? YES : NO;
    
    if (INVERTED_CONSTRAIN) {
        constrain = !constrain;
    }
    
    if (delta.x != 0) {
         scaleX = newDelta.x / delta.x;
    }
    
    if (delta.y != 0) {
        scaleY = newDelta.y / delta.y;
    }
    
    if (constrain) {
        float xSign = scaleX < 0 ? -1 : 1;
        float ySign = scaleY < 0 ? -1 : 1;
        
        scaleX = scaleY = MAX(fabs(scaleX), fabs(scaleY));
            
        // preserve the direction of the scaling
        scaleX *= xSign;
        scaleY *= ySign;
    }
    
    CGAffineTransform transform = CGAffineTransformMakeTranslation(pivot.x, pivot.y);
    transform = CGAffineTransformScale(transform, scaleX, scaleY);
    transform = CGAffineTransformTranslate(transform, -pivot.x, -pivot.y);
    
    return transform;
}

@end

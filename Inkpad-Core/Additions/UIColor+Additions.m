//
//  UIColor+Additions.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#import "UIColor+Additions.h"
#import "WDUtilities.h"
#if TARGET_OS_IPHONE
#import <OpenGLES/ES1/gl.h>
#else
#import <OpenGL/gl.h>
#endif

@implementation UIColor (WDAdditions)

+ (UIColor *) randomColor:(BOOL)includeAlpha
{
    float components[4];
    
    for (int i = 0; i < 4; i++) {
        components[i] = WDRandomFloat();
    }

    float alpha = (includeAlpha ? components[3] : 1.0f);
    alpha = 0.5 + (alpha * 0.5);
    
    return [UIColor colorWithRed:components[0] green:components[1] blue:components[2] alpha:alpha];
}

+ (UIColor *) saturatedRandomColor
{
    return [UIColor colorWithHue:WDRandomFloat() saturation:0.7f brightness:0.75f alpha:1.0];
}

- (void) openGLSet
{
    CGFloat w, r, g, b, a;
    
    if ([self getRed:&r green:&g blue:&b alpha:&a]) {
        glColor4f(r, g, b, a);
    } else {
        [self getWhite:&w alpha:&a];
        glColor4f(w, w, w, a);
    }
}

@end

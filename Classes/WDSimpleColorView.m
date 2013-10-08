//
//  WDSimpleColorView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDSimpleColorView.h"


@implementation WDSimpleColorView

@synthesize color = color_;

- (void) setColor:(UIColor *)color
{
    color_ = color;
    [self setNeedsDisplay];
}

- (void) drawRect:(CGRect)rect
{
    [color_ set];
    UIRectFill(self.bounds);
}

@end

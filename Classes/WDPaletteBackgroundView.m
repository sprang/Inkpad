//
//  WDPaletteBackgroundView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDPaletteBackgroundView.h"

@implementation WDPaletteBackgroundView

@synthesize cornerRadius;
@synthesize roundedCorners;

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    self.backgroundColor = nil;
    
    return self;
}

- (BOOL) hadRoundedCorners
{
    return (cornerRadius > 0 && self.roundedCorners);
}

- (void)drawRect:(CGRect)rect
{
    CGRect          bounds = self.bounds;
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    
    if ([self hadRoundedCorners]) {
        CGContextSaveGState(ctx);

        CGSize radii = CGSizeMake(self.cornerRadius, self.cornerRadius);
        UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                                         byRoundingCorners:self.roundedCorners
                                                               cornerRadii:radii];
        
        [shadowPath addClip];
    }
    
    // fill with white
    [[UIColor colorWithWhite:1.0f alpha:0.95f] set];
    UIRectFill(bounds);
    
    if ([self hadRoundedCorners]) {
        CGContextRestoreGState(ctx);
    }
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
}

@end

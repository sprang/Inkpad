//
//  WDColorIndicator.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#import "WDColorIndicator.h"
#import "WDColor.h"
#import "WDUtilities.h"

@implementation WDColorIndicator

@synthesize alphaMode = alphaMode_;
@synthesize color = color_;

+ (WDColorIndicator *) colorIndicator
{
    WDColorIndicator *indicator = [[WDColorIndicator alloc] initWithFrame:CGRectMake(0, 0, 25, 25)];
    return indicator;
}

- (id) initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
	}
    
    self.color = [WDColor whiteColor];
    self.opaque = NO;
    
    UIView *overlay = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:overlay];
    
    overlay.layer.borderColor = [UIColor whiteColor].CGColor;
    overlay.layer.borderWidth = 3;
    overlay.layer.cornerRadius = CGRectGetWidth(self.bounds) / 2.0f;
    
    overlay.layer.shadowOpacity = 0.5f;
    overlay.layer.shadowRadius = 1;
    overlay.layer.shadowOffset = CGSizeMake(0, 0);
    
	return self;
}

- (void) setColor:(WDColor *)color
{
    if ([color isEqual:color_]) {
        return;
    }
    
    color_ = color;
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    CGRect          bounds = CGRectInset([self bounds], 2, 2);
    
    if (self.alphaMode) {
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, bounds);
        CGContextClip(ctx);
        WDDrawTransparencyDiamondInRect(ctx, bounds);
        CGContextRestoreGState(ctx);
        [[self color] set];
    } else {
        [[[self color] opaqueUIColor] set];
    }
    
    CGContextFillEllipseInRect(ctx, bounds);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

@end

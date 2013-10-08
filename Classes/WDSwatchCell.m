//
//  WDSwatchCell.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "UIView+Additions.h"
#import "WDSwatchCell.h"
#import "WDPathPainter.h"

@implementation WDSwatchCell

@synthesize swatch = swatch_;
@synthesize shouldShowSelectionIndicator;

- (void) setSwatch:(id<WDPathPainter>)swatch
{
    if ([swatch isEqual:swatch_]) {
        return;
    }
    
    swatch_ = swatch;
    
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0);
    [swatch_ drawSwatchInRect:self.bounds];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    self.layer.contents = (id) image.CGImage;
    
    [self setNeedsDisplay];
}

- (void) setSelected:(BOOL)flag
{
    [super setSelected:flag];
    
    if (!shouldShowSelectionIndicator) {
        [selectedIndicator_ removeFromSuperview];
        selectedIndicator_ = nil;
        return;
    }
    
    if (flag && !selectedIndicator_) {
        UIImage *checkmark = [UIImage imageNamed:@"checkmark.png"];
        size_t width = checkmark.size.width;
        size_t height = checkmark.size.height;
        
        selectedIndicator_ = [[UIImageView alloc] initWithImage:checkmark];
        [self addSubview:selectedIndicator_];
        
        selectedIndicator_.sharpCenter = CGPointMake(CGRectGetMaxX(self.bounds) - ((width / 3) + 1),
                                                     CGRectGetMaxY(self.bounds) - ((height / 3) + 1));
    } else if (!flag && selectedIndicator_){
        [UIView animateWithDuration:0.1f
                         animations:^{ selectedIndicator_.alpha = 0; }
                         completion:^(BOOL finished){ [selectedIndicator_ removeFromSuperview]; }];
        selectedIndicator_ = nil;
    }
}

- (void) setHighlighted:(BOOL)highlighted
{
    if (highlighted) {
        highlightView = [[UIView alloc] initWithFrame:self.bounds];
        highlightView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.25f];
        [self insertSubview:highlightView atIndex:0];
    } else {
        [highlightView removeFromSuperview];
        highlightView = nil;
    }
}

@end

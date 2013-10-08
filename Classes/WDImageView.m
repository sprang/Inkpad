//
//  WDImageView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2013 Steve Sprang
//

#import "WDImageView.h"
#import "WDUtilities.h"

@implementation WDImageView

@synthesize image = image_;
@synthesize maximumDimension = maximumDimension_;

- (id)initWithImage:(UIImage *)image maxDimension:(float)maxDimension
{
    self = [super initWithFrame:WDRectFromSize(image.size)];
    
    if (!self) {
        return nil;
    }
    
    self.maximumDimension = maxDimension;
    self.image = image;
    
    return self;
}

- (void) setImage:(UIImage *)anImage
{
    image_ = anImage;
    
    // set the image frame so that it appears correctly on retina and non-retina displays
    CGRect frame = CGRectMake(0, 0, anImage.size.width, anImage.size.height);
    float aspectRatio = frame.size.width / frame.size.height;
    
    if (aspectRatio > 1.0f) {
        frame.size.width = self.maximumDimension;
        frame.size.height = (1.0f / aspectRatio) * self.maximumDimension;
    } else {
        frame.size.height = self.maximumDimension;
        frame.size.width = aspectRatio * self.maximumDimension;
    }
    
    self.frame = frame;
    [self setNeedsDisplay];
}

- (void) drawRect:(CGRect)rect
{
    [self.image drawInRect:self.bounds];
}

@end

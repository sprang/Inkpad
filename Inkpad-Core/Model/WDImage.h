//
//  WDImage.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import "WDElement.h"

@class WDImageData;
@class WDDrawing;

@interface WDImage : WDElement <NSCoding, NSCopying> {
    CGMutablePathRef    pathRef_;
    CGPoint             corner_[4];
}

@property (nonatomic, assign) CGAffineTransform transform;
@property (nonatomic, readonly) WDImageData *imageData;

+ (WDImage *) imageWithUIImage:(UIImage *)image inDrawing:(WDDrawing *)drawing;
- (id) initWithUIImage:(UIImage *)image inDrawing:(WDDrawing *)drawing;

- (CGRect) naturalBounds;
- (void) useTrackedImageData;

@end

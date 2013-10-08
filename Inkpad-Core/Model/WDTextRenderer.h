//
//  WDTextRenderer.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>


@protocol WDTextRenderer <NSObject>

@required
- (void) drawTextInContext:(CGContextRef)ctx drawingMode:(CGTextDrawingMode)mode;
- (void) drawTextInContext:(CGContextRef)ctx drawingMode:(CGTextDrawingMode)mode didClip:(BOOL *)didClip;

- (CGAffineTransform) transform;
- (NSArray *) outlines;

- (void) drawOpenGLTextOutlinesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform;

@end

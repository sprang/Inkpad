//
//  WDFillController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import "WDPathPainter.h"

@class WDColorController;
@class WDDrawingController;
@class WDGradientController;

typedef enum {
    kFillNone,
    kFillColor,
    kFillGradient
} WDFillMode;

@interface WDFillController : UIViewController {
    WDColorController       *colorController_;
    WDGradientController    *gradientController_;
    WDFillMode              fillMode_;
    UISegmentedControl      *modeSegment_;
    id<WDPathPainter>       fill_;
}

@property (nonatomic, weak) WDDrawingController *drawingController;
@end

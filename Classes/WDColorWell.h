//
//  WDColorWell.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import "WDPathPainter.h"

@class WDGradientStopIndicator;

@interface WDColorWell : UIButton {
    WDGradientStopIndicator     *gradientStop_;
    UIView                      *shadowView_;
}

@property (nonatomic, strong) id<WDPathPainter> painter;
@property (nonatomic, weak) UIBarButtonItem *barButtonItem;
@property (nonatomic, assign) BOOL strokeMode;
@property (nonatomic, assign) BOOL gradientStopMode;
@property (nonatomic, assign) BOOL shadowMode;

@end

//
//  WDColorSlider.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDColorIndicator;
@class WDColor;

typedef enum {
    WDColorSliderModeHue,
    WDColorSliderModeSaturation,
    WDColorSliderModeBrightness,
    WDColorSliderModeRed,
    WDColorSliderModeGreen,
    WDColorSliderModeBlue,
    WDColorSliderModeAlpha,
    WDColorSliderModeRedBalance,
    WDColorSliderModeGreenBalance,
    WDColorSliderModeBlueBalance
} WDColorSliderMode;

@interface WDColorSlider : UIControl {
    CGImageRef          hueImage_;
    WDColor             *color_;
    float               value_;
    WDColorIndicator    *indicator_;
    CGShadingRef        shadingRef_;
    WDColorSliderMode   mode_;
    BOOL                reversed_;
}

@property (nonatomic, assign) WDColorSliderMode mode;
@property (nonatomic, readonly) float floatValue;
@property (nonatomic, strong) WDColor *color;
@property (nonatomic, assign) BOOL reversed;
@property (nonatomic, strong, readonly) WDColorIndicator *indicator;

@end

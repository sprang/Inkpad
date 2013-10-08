//
//  WDHueSaturationController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import "WDColorAdjustmentController.h"

@class WDColorSlider;
@class WDHueShifter;

@interface WDHueSaturationController : WDColorAdjustmentController {
    IBOutlet WDHueShifter       *hueShifter_;
    IBOutlet WDColorSlider      *saturationSlider_;
    IBOutlet WDColorSlider      *brightnessSlider_;
    
    IBOutlet UILabel            *hueLabel_;
    IBOutlet UILabel            *saturationLabel_;
    IBOutlet UILabel            *brightnessLabel_;
    
    float                       hueShift_;
    float                       saturationShift_;
    float                       brightnessShift_;
}

@end

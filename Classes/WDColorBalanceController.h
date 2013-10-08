//
//  WDColorBalanceController.h
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

@interface WDColorBalanceController : WDColorAdjustmentController {
    IBOutlet WDColorSlider      *redSlider_;
    IBOutlet WDColorSlider      *greenSlider_;
    IBOutlet WDColorSlider      *blueSlider_;
    
    IBOutlet UILabel            *redLabel_;
    IBOutlet UILabel            *greenLabel_;
    IBOutlet UILabel            *blueLabel_;
        
    float                       redShift_;
    float                       greenShift_;
    float                       blueShift_;
}

@end

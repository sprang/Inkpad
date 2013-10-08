//
//  WDColorController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDColorSlider;
@class WDColorWell;
@class WDColor;

typedef enum {
    WDColorSpaceRGB,
    WDColorSpaceHSB,
} WDColorSpace;

@interface WDColorController : UIViewController {
    IBOutlet WDColorSlider      *component0Slider_;
    IBOutlet WDColorSlider      *component1Slider_;
    IBOutlet WDColorSlider      *component2Slider_;
    IBOutlet WDColorSlider      *alphaSlider_;
    
    IBOutlet UILabel            *component0Name_;
    IBOutlet UILabel            *component1Name_;
    
    IBOutlet UILabel            *component0Value_;
    IBOutlet UILabel            *component1Value_;
    IBOutlet UILabel            *component2Value_;
    IBOutlet UILabel            *alphaValue_;
    
    IBOutlet UIButton           *colorSpaceButton_;
    
    WDColorSpace                 colorSpace_;
}

@property (nonatomic, strong) WDColor *color;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL action;
@property (weak, nonatomic, readonly) WDColorWell *colorWell;

- (IBAction) takeColorSpaceFrom:(id)sender;

@end

extern NSString *WDColorSpaceDefault;

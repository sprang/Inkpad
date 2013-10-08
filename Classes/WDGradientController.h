//
//  WDGradientController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDColorController;
@class WDColorWell;
@class WDGradientEditor;
@class WDGradient;
@class WDColor;

@interface WDGradientController : UIViewController {
    IBOutlet WDGradientEditor       *gradientEditor_;
    IBOutlet WDColorWell            *colorWell_;
    IBOutlet UIButton               *typeButton_;
}

@property (nonatomic, strong) WDGradient *gradient;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL action;
@property (nonatomic, weak) WDColorController *colorController;
@property (nonatomic, assign) BOOL inactive;

- (IBAction) takeGradientTypeFrom:(id)sender;
- (IBAction) takeGradientStopsFrom:(id)sender;

- (void) colorSelected:(WDColor *)color;
- (void) setColor:(WDColor *)color;

- (void) reverseGradient:(id)sender;
- (void) distributeGradientStops:(id)sender;

@end

//
//  WDShadowController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDAnglePicker;
@class WDBlendModeController;
@class WDColorController;
@class WDDrawingController;
@class WDSparkSlider;

@interface WDShadowController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    WDColorController       *colorController_;
	WDBlendModeController	*blendModeController_;
    
    IBOutlet WDSparkSlider  *radius_;
    IBOutlet WDSparkSlider  *offset_;
    IBOutlet WDAnglePicker  *angle_;
    IBOutlet UISlider       *opacitySlider_;
    IBOutlet UILabel        *opacityLabel_;
    IBOutlet UISwitch       *shadowSwitch_;
	IBOutlet UITableView	*blendModeTableView_;
    IBOutlet UIButton       *increment;
    IBOutlet UIButton       *decrement;
	CGBlendMode				blendMode_;
}

@property (nonatomic, weak) WDDrawingController *drawingController;

- (IBAction) toggleShadow:(id)sender;

@end

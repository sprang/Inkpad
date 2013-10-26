//
//  WDStrokeController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDDrawingController;
@class WDColorController;
@class WDLineAttributePicker;
@class WDSparkSlider;
@class WDStrokeStyle;

typedef enum {
    kStrokeNone,
    kStrokeColor,
} WDStrokeMode;

@interface WDStrokeController : UIViewController {
    IBOutlet UISlider               *widthSlider_;
    IBOutlet UILabel                *widthLabel_;
    IBOutlet WDLineAttributePicker  *capPicker_;
    IBOutlet WDLineAttributePicker  *joinPicker_;
    
    IBOutlet UIButton               *increment;
    IBOutlet UIButton               *decrement;
    
    IBOutlet UISwitch               *dashSwitch_;
    IBOutlet WDSparkSlider          *dash0_;
    IBOutlet WDSparkSlider          *dash1_;
    IBOutlet WDSparkSlider          *gap0_;
    IBOutlet WDSparkSlider          *gap1_;
    
    IBOutlet UIButton               *arrowButton_;
    
    WDColorController               *colorController_;
    UISegmentedControl              *modeSegment_;
    
    WDStrokeMode                    mode_;
}

@property (nonatomic, weak) WDDrawingController *drawingController;

- (IBAction) toggleDash:(id)sender;

- (IBAction) increment:(id)sender;
- (IBAction) decrement:(id)sender;
- (IBAction) takeStrokeWidthFrom:(id)sender;
- (IBAction) takeFinalStrokeWidthFrom:(id)sender;
- (IBAction) showArrowheads:(id)sender;

@end

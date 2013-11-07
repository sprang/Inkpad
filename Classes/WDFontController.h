//
//  WDTextController.h
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
@class WDText;

@interface WDFontController : UIViewController <UITableViewDelegate, UITableViewDataSource> {\
    IBOutlet UIView                 *controls_;
    IBOutlet UITableView            *faceTable_;
    IBOutlet UITableView            *familyTable_;
    IBOutlet UILabel                *sizeLabel_;
    IBOutlet UISlider               *sizeSlider_;
    IBOutlet UISegmentedControl     *alignment_;
    IBOutlet UIBarButtonItem        *familiesButton_;
    NSString                        *selectedFontName_;
    NSString                        *selectedFamilyName_;
}

@property (nonatomic, weak) WDDrawingController *drawingController;
@property (nonatomic, strong) NSString *selectedFontName;
@property (nonatomic, strong) NSString *selectedFamilyName;

- (IBAction) takeFontSizeFrom:(id)sender;
- (IBAction) takeAlignmentFrom:(id)sender;

- (IBAction) increment:(id)sender;
- (IBAction) decrement:(id)sender;

- (void) scrollToSelectedFont;

@end


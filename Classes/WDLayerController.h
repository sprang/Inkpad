//
//  WDLayerController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDDrawing;
@class WDLayerCell;

@interface WDLayerController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate> {
    IBOutlet UITableView        *layerTable_;
    UITextField                 *activeField_;
    
    UISlider                    *opacitySlider_;
    UILabel                     *opacityLabel_;
    UIButton                    *decrementButton_;
    UIButton                    *incrementButton_;
    
    NSArray                     *toolbarItems_;
}

@property (nonatomic, weak) WDDrawing *drawing;
@property (nonatomic, weak) IBOutlet WDLayerCell *layerCell;

- (void) selectActiveLayer;
- (void) updateOpacity;

@end

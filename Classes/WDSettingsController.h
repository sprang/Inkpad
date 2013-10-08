//
//  WDSettingsController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDDrawing;

@interface WDSettingsController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate> {
    IBOutlet UITableView    *table_;
    NSArray                 *configuration_;
    UITextField             *gridSpacing_;
    UITableViewCell         *unitsCell_;
    NSNumberFormatter       *formatter_;
}

@property (nonatomic, weak) WDDrawing *drawing;

- (NSString *) dimensionsString;

@end


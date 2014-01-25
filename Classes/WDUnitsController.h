//
//  WDUnitsController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@class WDDrawing;

@interface WDUnitsController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate> {
    IBOutlet UITableView    *table_;
    NSArray                 *units_;
    
    NSNumberFormatter       *formatter_;
    UITextField             *width_;
    UITextField             *height_;
}

@property (nonatomic, weak) WDDrawing *drawing;

+ (float) preferredViewWidth;

@end

extern NSString *WDCustomDrawingSizeChanged;

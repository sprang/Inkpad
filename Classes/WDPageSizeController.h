//
//  WDPageSizeController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@interface WDPageSizeController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    IBOutlet UITableView    *table_;
    NSArray                 *configuration_;
    UITableViewCell         *customCell_;
}

@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL action;
@property (nonatomic, readonly) CGSize size;
@property (weak, nonatomic, readonly) NSString *units;

@end

extern NSString *WDPageOrientation;
extern NSString *WDPageSize;

//
//  WDBlendModeController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDDrawingController;

@interface WDBlendModeController : UIViewController <UITableViewDataSource, UITableViewDelegate>
{
	NSArray *blendModeNames_;
	IBOutlet UITableView *tableView_;
    NSUInteger selectedRow_;
}

@property (nonatomic, weak) WDDrawingController *drawingController;

- (NSString *) displayNameForBlendMode:(CGBlendMode)blendMode;

@end

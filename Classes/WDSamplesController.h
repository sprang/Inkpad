//
//  WDSamplesController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@protocol WDSamplesControllerDelegate;

@interface WDSamplesController : UIViewController <UITableViewDelegate, UITableViewDataSource> {}

@property (nonatomic, weak) id <WDSamplesControllerDelegate> delegate;
@property (nonatomic, strong) IBOutlet UITableView *contentsTable;

@end

@protocol WDSamplesControllerDelegate <NSObject>
@optional
- (void) samplesController:(WDSamplesController *)controller didSelectURLs:(NSArray *)sampleURLs;
@end

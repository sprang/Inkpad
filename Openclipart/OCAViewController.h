//
//  OCAViewController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import <UIKit/UIKit.h>
#import "OCADownloader.h"

@class OCAEntry;

@interface OCAViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate,
                                                        UISearchBarDelegate, OCADownloaderDelegate>

@property (nonatomic) IBOutlet UICollectionView *collectionView;
@property (nonatomic) IBOutlet UISearchBar *searchBar;
@property (nonatomic) OCAEntry *selectedEntry;
@property (nonatomic, getter=isVisible) BOOL visible;

- (void) setImportTarget:(id)target action:(SEL)action;
- (void) setActionTitle:(NSString *)title;

@end

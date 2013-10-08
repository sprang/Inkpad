//
//  WDLayerCell.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDLayer;
@class WDSimpleColorView;

@interface WDLayerCell : UITableViewCell

@property (nonatomic, weak) WDLayer *drawingLayer;
@property (nonatomic, strong) IBOutlet WDSimpleColorView *colorView;
@property (nonatomic, strong) IBOutlet UITextField *titleField;
@property (nonatomic, strong) IBOutlet UIButton *visibleButton;
@property (nonatomic, strong) IBOutlet UIImageView *thumbnail;
@property (nonatomic, strong) IBOutlet UIButton *lockButton;
@property (nonatomic, strong) IBOutlet UITextField *opacityField;

- (void) updateLayerName;
- (void) updateVisibilityButton;
- (void) updateLockedStatusButton;
- (void) updateThumbnail;
- (void) updateOpacity;

@end

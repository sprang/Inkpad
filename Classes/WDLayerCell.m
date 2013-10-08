//
//  WDLayerCell.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDLayerCell.h"
#import "WDLayer.h"
#import "WDSimpleColorView.h"

#define kFontSize       19.0f

@implementation WDLayerCell

@synthesize drawingLayer = layer_;
@synthesize colorView;
@synthesize titleField;
@synthesize visibleButton;
@synthesize thumbnail;
@synthesize lockButton;
@synthesize opacityField;

- (void) awakeFromNib
{
    [visibleButton addTarget:self action:@selector(toggleVisibility:) forControlEvents:UIControlEventTouchUpInside];
    [lockButton addTarget:self action:@selector(toggleLocked:) forControlEvents:UIControlEventTouchUpInside];
    
    UIImageView *selectionView = [[UIImageView alloc] init];
    self.selectedBackgroundView = selectionView;
    selectionView.backgroundColor = [UIColor colorWithRed:(193.0f / 255) green:(220.0f / 255) blue:1.0f alpha:0.666f];
}

- (void) setDrawingLayer:(WDLayer *)layer
{
    layer_ = layer;
    
    thumbnail.image = layer.thumbnail;
    
    colorView.color = [layer highlightColor];
    
    [self updateLayerName];
    [self updateVisibilityButton];
    [self updateLockedStatusButton];  
    [self updateOpacity];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];
    
    if (selected) {
        titleField.font = [UIFont boldSystemFontOfSize:kFontSize];
    } else {
        titleField.font = [UIFont systemFontOfSize:kFontSize];
    }
    
    titleField.userInteractionEnabled = selected;
}

- (void) updateLayerName
{
    titleField.text = layer_.name;
}

- (void) updateVisibilityButton
{
    UIImage *image = [[UIImage imageNamed:(layer_.hidden ? @"hidden.png" : @"visible.png")]
                      imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [visibleButton setImage:image forState:UIControlStateNormal];
}

- (void) updateLockedStatusButton
{
    UIImage *image = [[UIImage imageNamed:(layer_.locked ? @"lock.png" : @"unlock.png")]
                      imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [lockButton setImage:image forState:UIControlStateNormal];
}

- (void) updateOpacity
{
    int value = round(layer_.opacity * 100);
    opacityField.text = [NSString stringWithFormat:@"%d%%", value];
}

- (void) updateThumbnail
{
    thumbnail.image = layer_.thumbnail;
}

- (void) toggleVisibility:(id)sender
{
    [layer_ toggleVisibility];
}

- (void) toggleLocked:(id)sender
{
    [layer_ toggleLocked];
}

@end

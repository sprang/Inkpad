//
//  WDMenu.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>


@interface WDMenu : UIControl {
    NSMutableArray          *rects_;
    NSMutableArray          *items_;
    BOOL                    visible_;
}

@property (nonatomic, assign) int indexOfSelectedItem;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, assign) BOOL visible;
@property (nonatomic, assign) CGPoint origin;
@property (nonatomic, weak) UIPopoverController *popover;
@property (nonatomic, weak) id delegate;

- (id) initWithItems:(NSArray *)items;
- (void) dismiss;

@end

//
//  WDToolView.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDCanvas;
@class WDToolButton;

@interface WDToolView : UIView

@property (nonatomic, strong) NSArray *tools;
@property (nonatomic, weak) WDCanvas *canvas;
@property (nonatomic, weak) WDToolButton *owner;

- (id) initWithTools:(NSArray *)tools;

@end

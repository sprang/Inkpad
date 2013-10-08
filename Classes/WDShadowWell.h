//
//  WDShadowWell.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDShadow;

@interface WDShadowWell : UIButton  

@property (nonatomic, strong) WDShadow *shadow;
@property (nonatomic, assign) float opacity;
@property (nonatomic, weak) UIBarButtonItem *barButtonItem;

@end

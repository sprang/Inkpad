//
//  WDBlockingView.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@interface WDBlockingView : UIView {
    BOOL        sendAction_;
}

@property (nonatomic, assign) SEL action;
@property (nonatomic, weak) id target;
@property (nonatomic, strong) NSArray *passthroughViews;

- (void) setShadowCenter:(CGPoint)center radius:(float)radius;

@end

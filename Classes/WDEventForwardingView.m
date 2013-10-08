//
//  WDEventForwardingView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#import "WDEventForwardingView.h"


@implementation WDEventForwardingView

@synthesize forwardToView = forwardToView_;

- (void) awakeFromNib
{
    self.opaque = NO;
    self.backgroundColor = nil;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    return (view == self) ? forwardToView_ : view;
}

@end

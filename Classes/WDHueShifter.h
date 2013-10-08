//
//  WDHueShifter.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@class WDHueIndicator;

@interface WDHueIndicatorOverlay : UIView
@property (nonatomic, weak) WDHueIndicator *indicator;
@end

@interface WDHueIndicator : UIView

@property (nonatomic, strong) WDColor *color;

- (CGRect) colorRect;

@end

@interface WDHueShifter : UIControl {
    CGImageRef      offsetHueImage_;
    CGImageRef      hueImage_;
    float           value_;
    float           initialValue_;
    CGPoint         initialPt_;
    
    WDHueIndicator  *indicator_;
    
}

@property (nonatomic, assign) float floatValue;

@end

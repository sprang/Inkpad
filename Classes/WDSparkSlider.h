//
//  WDSparkSlider.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@interface WDSparkSlider : UIControl {
    UILabel         *valueLabel_;
    UIImageView     *indicator_;
    
    CGPoint         initialPt_;
    NSUInteger      initialValue_;
    
    BOOL            dragging_;
    BOOL            moved_;
}

@property (nonatomic, readonly) UILabel *title;
@property (weak, nonatomic, readonly) NSNumber *numberValue;
@property (nonatomic, assign) float value;
@property (nonatomic, assign) float minValue;
@property (nonatomic, assign) float maxValue;

- (void) updateIndicator;

@end

//
//  WDGradientEditor.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDColor;
@class WDGradient;
@class WDGradientController;
@class WDGradientStopIndicator;

@interface WDGradientEditor : UIControl {
    NSMutableArray              *indicators_;
    WDGradientStopIndicator     *activeIndicator_;
    WDGradientStopIndicator     *indicatorToRemove_;
    WDGradientStopIndicator     *indicatorToDrag_;
    BOOL                        moved_;
}

@property (nonatomic, strong) WDGradient *gradient;
@property (nonatomic, strong) WDGradient *renderingGradient;
@property (weak, nonatomic, readonly) NSArray *stops;
@property (nonatomic, weak) WDGradientController *controller;
@property (nonatomic, assign) BOOL inactive;

- (void) setColor:(WDColor *)color;
- (void) setActiveIndicator:(WDGradientStopIndicator *)indicator;
- (WDGradientStopIndicator *) stopIndicatorWithRatio:(float)ratio;

@end

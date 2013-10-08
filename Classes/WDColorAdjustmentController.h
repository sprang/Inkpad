//
//  WDColorAdjustmentController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDBlockingView;
@class WDCanvas;
@class WDDrawingController;
@class WDModalTitleBar;
@class WDPaletteBackgroundView;

@interface WDColorAdjustmentController : UIViewController <UIGestureRecognizerDelegate> {
    IBOutlet WDModalTitleBar            *navBar_;
    IBOutlet WDPaletteBackgroundView    *background_;
    
    NSNumberFormatter                   *formatter_;
    
    WDBlockingView                      *blockingView_;
}

@property (nonatomic, weak) WDDrawingController *drawingController;
@property (nonatomic, weak) WDCanvas *canvas;
@property (nonatomic, strong) NSString *defaultsName;
@property (nonatomic, readonly) NSNumberFormatter *formatter;

- (IBAction) cancel:(id)sender;
- (IBAction) accept:(id)sender;

- (void) bringOnScreenAnimated:(BOOL)animated;
- (void) runModalOverView:(UIView *)view;

- (void) resetShiftsToZero;

@end

//
//  WDColorBalanceController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDCanvas.h"
#import "WDCanvasController.h"
#import "WDColor.h"
#import "WDColorBalanceController.h"
#import "WDColorSlider.h"
#import "WDDrawingController.h"

@implementation WDColorBalanceController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }

    self.defaultsName = @"color balance";
    
    return self;
}

- (void) performAdjustment
{
    [self.drawingController adjustColor:^(WDColor *color) { return [color colorBalanceRed:redShift_
                                                                               green:greenShift_
                                                                                blue:blueShift_]; }
                             scope:(WDColorAdjustStroke | WDColorAdjustFill | WDColorAdjustShadow)];
}

- (void) takeShiftFrom:(WDColorSlider *)sender
{
    float value = ([sender floatValue] - 0.5f) * 2;
 
    if (sender.tag == 0) {
        [redSlider_ setColor:[[WDColor cyanColor] blendedColorWithFraction:[sender floatValue] ofColor:[WDColor redColor]]];
        redShift_ = value;
        redLabel_.text = [self.formatter stringFromNumber:@((int) roundf(redShift_ * 100))];
    } else if (sender.tag == 1) {
        [greenSlider_ setColor:[[WDColor magentaColor] blendedColorWithFraction:[sender floatValue] ofColor:[WDColor greenColor]]];
        greenShift_ = value;
        greenLabel_.text = [self.formatter stringFromNumber:@((int) roundf(greenShift_ * 100))];
    } else {
        [blueSlider_ setColor:[[WDColor yellowColor] blendedColorWithFraction:[sender floatValue] ofColor:[WDColor blueColor]]];
        blueShift_ = value;
        blueLabel_.text = [self.formatter stringFromNumber:@((int) roundf(blueShift_ * 100))];
    }
}

- (void) takeFinalShiftFrom:(WDColorSlider *)sender
{
    [self performAdjustment];
}

- (void) resetShiftsToZero
{
    redShift_ = greenShift_ = blueShift_ = 0.0f;
    
    [redSlider_ setColor:[[WDColor cyanColor] blendedColorWithFraction:0.5f ofColor:[WDColor redColor]]];
    [greenSlider_ setColor:[[WDColor magentaColor] blendedColorWithFraction:0.5f ofColor:[WDColor greenColor]]];
    [blueSlider_ setColor:[[WDColor yellowColor] blendedColorWithFraction:0.5f ofColor:[WDColor blueColor]]];
    
    // reset labels
    redLabel_.text = @"0";
    greenLabel_.text = @"0";
    blueLabel_.text = @"0";
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [redSlider_ setMode:WDColorSliderModeRedBalance];
    [greenSlider_ setMode:WDColorSliderModeGreenBalance];
    [blueSlider_ setMode:WDColorSliderModeBlueBalance];
    
    UIControlEvents dragEvents = (UIControlEventTouchDown | UIControlEventTouchDragInside | UIControlEventTouchDragOutside);
    
    [redSlider_ addTarget:self action:@selector(takeShiftFrom:) forControlEvents:dragEvents];
    [greenSlider_ addTarget:self action:@selector(takeShiftFrom:) forControlEvents:dragEvents];
    [blueSlider_ addTarget:self action:@selector(takeShiftFrom:) forControlEvents:dragEvents];
    
    UIControlEvents touchEndEvents = (UIControlEventTouchUpInside | UIControlEventTouchUpOutside);
    
    [redSlider_ addTarget:self action:@selector(takeFinalShiftFrom:) forControlEvents:touchEndEvents];
    [greenSlider_ addTarget:self action:@selector(takeFinalShiftFrom:) forControlEvents:touchEndEvents];
    [blueSlider_ addTarget:self action:@selector(takeFinalShiftFrom:) forControlEvents:touchEndEvents];
}

@end

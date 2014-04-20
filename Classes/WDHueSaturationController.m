//
//  WDHueSaturationController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDDrawingController.h"
#import "WDColor.h"
#import "WDColorSlider.h"
#import "WDHueSaturationController.h"
#import "WDHueShifter.h"

@implementation WDHueSaturationController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    self.defaultsName = @"hue/saturation";
    
    return self;
}

- (void) performAdjustment
{
    [self.drawingController adjustColor:^(WDColor *color) { return [color adjustHue:hueShift_
                                                                    saturation:saturationShift_
                                                                    brightness:brightnessShift_]; }
                             scope:(WDColorAdjustStroke | WDColorAdjustFill | WDColorAdjustShadow)];

}

- (void) takeShiftFrom:(WDColorSlider *)sender
{
    if (sender.tag == 0) {
        hueShift_ = [sender floatValue] / 2.0f;
        int h = (int) roundf(hueShift_ * 360);
        hueLabel_.text = [self.formatter stringFromNumber:@(h)];
    } else if (sender.tag == 1) {
        float saturation = [sender floatValue];
        
        [saturationSlider_ setColor:[WDColor colorWithHue:0.5f saturation:saturation brightness:1 alpha:1]];
        saturationShift_ = (saturation - 0.5f) * 2;
        saturationLabel_.text = [self.formatter stringFromNumber:@((int) roundf(saturationShift_ * 100))];
    } else {
        float brightness = [sender floatValue];
        
        [brightnessSlider_ setColor:[WDColor colorWithHue:0 saturation:0 brightness:brightness alpha:1]];
        brightnessShift_ = (brightness - 0.5f) * 2;
        brightnessLabel_.text = [self.formatter stringFromNumber:@((int) roundf(brightnessShift_ * 100))];
    }
}

- (void) takeFinalShiftFrom:(WDColorSlider *)sender
{
    [self performAdjustment];
}

#pragma mark - View lifecycle

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [saturationSlider_ setMode:WDColorSliderModeSaturation];
    [brightnessSlider_ setMode:WDColorSliderModeBrightness];
    
    UIControlEvents dragEvents = (UIControlEventTouchDown | UIControlEventTouchDragInside | UIControlEventTouchDragOutside);
    
    [hueShifter_ addTarget:self action:@selector(takeShiftFrom:) forControlEvents:dragEvents];
    [saturationSlider_ addTarget:self action:@selector(takeShiftFrom:) forControlEvents:dragEvents];
    [brightnessSlider_ addTarget:self action:@selector(takeShiftFrom:) forControlEvents:dragEvents];
    
    UIControlEvents touchEndEvents = (UIControlEventTouchUpInside | UIControlEventTouchUpOutside);
    
    [hueShifter_ addTarget:self action:@selector(takeFinalShiftFrom:) forControlEvents:touchEndEvents];
    [saturationSlider_ addTarget:self action:@selector(takeFinalShiftFrom:) forControlEvents:touchEndEvents];
    [brightnessSlider_ addTarget:self action:@selector(takeFinalShiftFrom:) forControlEvents:touchEndEvents];

}

- (void) resetShiftsToZero
{
    hueShift_ = 0;
    saturationShift_ = 0;
    brightnessShift_ = 0;
    
    // reset sliders
    [hueShifter_ setFloatValue:hueShift_];
    [saturationSlider_ setColor:[WDColor colorWithHue:0.5 saturation:((saturationShift_ / 2) + 0.5) brightness:1 alpha:1]];
    [brightnessSlider_ setColor:[WDColor colorWithHue:0 saturation:0 brightness:((brightnessShift_ / 2) + 0.5) alpha:1]];
    
    // reset labels
    hueLabel_.text = [self.formatter stringFromNumber:@((int) roundf(hueShift_ * 360))];
    saturationLabel_.text = [self.formatter stringFromNumber:@((int) roundf(saturationShift_ * 100))];
    brightnessLabel_.text = [self.formatter stringFromNumber:@((int) roundf(brightnessShift_ * 100))];
}

@end

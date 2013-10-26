//
//  WDColorController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDColorController.h"
#import "WDColorSlider.h"
#import "WDColorWell.h"
#import "WDColor.h"

NSString *WDColorSpaceDefault = @"WDColorSpaceDefault";

@implementation WDColorController

@synthesize color = color_;
@synthesize target = target_;
@synthesize action = action_;
@synthesize colorWell = colorWell_;

- (void) setColor:(WDColor *)color notify:(BOOL)notify
{
    color_ = color;
    
    [component0Slider_ setColor:color_];
    [component1Slider_ setColor:color_];
    [component2Slider_ setColor:color_];
    [alphaSlider_ setColor:color_];
    
    [colorWell_ setPainter:color_];
    
    if (colorSpace_ == WDColorSpaceHSB) {
        component0Value_.text = [NSString stringWithFormat:@"%d°", (int) round(color_.hue * 360)];
        component1Value_.text = [NSString stringWithFormat:@"%d%%", (int) round(color_.saturation * 100)];
        component2Value_.text = [NSString stringWithFormat:@"%d%%", (int) round(color_.brightness * 100)];
    } else {
        component0Value_.text = [NSString stringWithFormat:@"%d", (int) round(color_.red * 255)];
        component1Value_.text = [NSString stringWithFormat:@"%d", (int) round(color_.green * 255)];
        component2Value_.text = [NSString stringWithFormat:@"%d", (int) round(color_.blue * 255)];
    }
    
    alphaValue_.text = [NSString stringWithFormat:@"%d%%", (int) round(color_.alpha * 100)];
    
    if (notify) {
        [[UIApplication sharedApplication] sendAction:action_ to:target_ from:self forEvent:nil];
    }
}

- (void) setColor:(WDColor *)color
{
    [self setColor:color notify:NO];
}

- (void) setColorSpace:(WDColorSpace)space
{
    colorSpace_ = space;
    
    if (space == WDColorSpaceRGB) {
        component0Slider_.mode = WDColorSliderModeRed;
        component1Slider_.mode = WDColorSliderModeGreen;
        component2Slider_.mode = WDColorSliderModeBlue;
        
        component0Name_.text = @"R";
        component1Name_.text = @"G";
        
        [colorSpaceButton_ setTitle:@"HSB" forState:UIControlStateNormal];
    } else {
        component0Slider_.mode = WDColorSliderModeHue;
        component1Slider_.mode = WDColorSliderModeSaturation;
        component2Slider_.mode = WDColorSliderModeBrightness;
        
        component0Name_.text = @"H";
        component1Name_.text = @"S";
        
        [colorSpaceButton_ setTitle:@"RGB" forState:UIControlStateNormal];
    }
    
    [self setColor:color_ notify:NO];
    
    [[NSUserDefaults standardUserDefaults] setInteger:colorSpace_ forKey:WDColorSpaceDefault];
}

- (void) takeColorSpaceFrom:(id)sender
{
    if (colorSpace_ == WDColorSpaceRGB) {
        [self setColorSpace:WDColorSpaceHSB];
    } else {
        [self setColorSpace:WDColorSpaceRGB];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = nil;
    self.view.opaque = NO;
    
    [self setColorSpace:(WDColorSpace)[[NSUserDefaults standardUserDefaults] integerForKey:WDColorSpaceDefault]];
    alphaSlider_.mode = WDColorSliderModeAlpha;
    
    // set up connections
    UIControlEvents dragEvents = (UIControlEventTouchDown | UIControlEventTouchDragInside | UIControlEventTouchDragOutside);
    
    [component0Slider_ addTarget:self action:@selector(takeComponent0From:) forControlEvents:dragEvents];
    [component1Slider_ addTarget:self action:@selector(takeComponent1From:) forControlEvents:dragEvents];
    [component2Slider_ addTarget:self action:@selector(takeComponent2From:) forControlEvents:dragEvents];
    [alphaSlider_ addTarget:self action:@selector(takeOpacityFrom:) forControlEvents:dragEvents];
    
    UIControlEvents touchEndEvents = (UIControlEventTouchUpInside | UIControlEventTouchUpOutside);
    
    [component0Slider_ addTarget:self action:@selector(takeFinalComponent0From:) forControlEvents:touchEndEvents];
    [component1Slider_ addTarget:self action:@selector(takeFinalComponent1From:) forControlEvents:touchEndEvents];
    [component2Slider_ addTarget:self action:@selector(takeFinalComponent2From:) forControlEvents:touchEndEvents];
    [alphaSlider_ addTarget:self action:@selector(takeFinalOpacityFrom:) forControlEvents:touchEndEvents];
}

- (void) takeComponent0From:(id)sender notify:(BOOL)notify
{
    WDColor     *newColor;
    float       component0 = [sender floatValue];
    
    if (colorSpace_ == WDColorSpaceHSB) {
        newColor = [WDColor colorWithHue:component0 saturation:[color_ saturation] brightness:[color_ brightness] alpha:[color_ alpha]];
    } else {
        newColor = [WDColor colorWithRed:component0 green:[color_ green] blue:[color_ blue] alpha:[color_ alpha]];
    }
    
    [self setColor:newColor notify:notify];
}

- (void) takeComponent1From:(id)sender notify:(BOOL)notify
{
    WDColor     *newColor;
    float       component1 = [sender floatValue];
    
    if (colorSpace_ == WDColorSpaceHSB) {
        newColor = [WDColor colorWithHue:[color_ hue] saturation:component1 brightness:[color_ brightness] alpha:[color_ alpha]];
    } else {
        newColor = [WDColor colorWithRed:[color_ red] green:component1 blue:[color_ blue] alpha:[color_ alpha]];
    }
    
    [self setColor:newColor notify:notify];
}

- (void) takeComponent2From:(id)sender notify:(BOOL)notify
{
    WDColor     *newColor;
    float       component2 = [sender floatValue];
    
    if (colorSpace_ == WDColorSpaceHSB) {
        newColor = [WDColor colorWithHue:[color_ hue] saturation:[color_ saturation] brightness:component2 alpha:[color_ alpha]];
    } else {
        newColor = [WDColor colorWithRed:[color_ red] green:[color_ green] blue:component2 alpha:[color_ alpha]];
    }
    
    [self setColor:newColor notify:notify];
}

- (void) takeOpacityFrom:(id)sender
{
    float alpha = [sender floatValue];
    [self setColor:[color_ colorWithAlphaComponent:alpha] notify:NO];
}

- (void) takeComponent0From:(id)sender
{
    [self takeComponent0From:sender notify:NO];
}

- (void) takeComponent1From:(id)sender
{
    [self takeComponent1From:sender notify:NO];
}

- (void) takeComponent2From:(id)sender
{
    [self takeComponent2From:sender notify:NO];
}

- (void) takeFinalComponent0From:(id)sender
{
    [self takeComponent0From:sender notify:YES];
}

- (void) takeFinalComponent1From:(id)sender
{
    [self takeComponent1From:sender notify:YES];
}

- (void) takeFinalComponent2From:(id)sender
{
    [self takeComponent2From:sender notify:YES];
}

- (void) takeFinalOpacityFrom:(id)sender
{
    float alpha = [sender floatValue];
    [self setColor:[color_ colorWithAlphaComponent:alpha] notify:YES];
}

@end

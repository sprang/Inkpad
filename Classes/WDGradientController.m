//
//  WDGradientController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDColorController.h"
#import "WDColorWell.h"
#import "WDColor.h"
#import "WDGradient.h"
#import "WDGradientController.h"
#import "WDGradientEditor.h"

#define kInactiveAlpha  0.5

@implementation WDGradientController

@synthesize gradient = gradient_;
@synthesize target = target_;
@synthesize action = action_;
@synthesize colorController = colorController_;
@synthesize inactive = inactive_;

- (IBAction) takeGradientTypeFrom:(id)sender
{
    if (gradient_.type == kWDRadialGradient) {
        [self setGradient:[gradient_ gradientWithType:kWDLinearGradient]];
    } else {
        [self setGradient:[gradient_ gradientWithType:kWDRadialGradient]];
    }
    
    [[UIApplication sharedApplication] sendAction:action_ to:target_ from:self forEvent:nil];
}

- (void) setGradient:(WDGradient *)gradient
{
    gradient_ = gradient;
    
    [colorWell_ setPainter:gradient_];
    [gradientEditor_ setGradient:gradient_];
    
    if (gradient_.type == kWDLinearGradient) {
        [typeButton_ setImage:[UIImage imageNamed:@"linear.png"] forState:UIControlStateNormal];
    } else {
        [typeButton_ setImage:[UIImage imageNamed:@"radial.png"] forState:UIControlStateNormal];
    }
}

- (IBAction) takeGradientStopsFrom:(id)sender
{
    WDGradientEditor *editor = (WDGradientEditor *) sender;
    
    self.gradient = [self.gradient gradientWithStops:[editor stops]];
    
    [[UIApplication sharedApplication] sendAction:action_ to:target_ from:self forEvent:nil];
}
    
- (void) setColor:(WDColor *)color
{
    [gradientEditor_ setColor:color];
}

- (void) colorSelected:(WDColor *)color
{
    [colorController_ setColor:color];
}

- (void) setInactive:(BOOL)inactive
{
    if (inactive_ == inactive) {
        return;
    }
    
    inactive_ = inactive;
    gradientEditor_.inactive = inactive;
}

- (void) reverseGradient:(id)sender
{
    self.gradient = [self.gradient gradientByReversing];
    [[UIApplication sharedApplication] sendAction:action_ to:target_ from:self forEvent:nil];
}

- (void) distributeGradientStops:(id)sender
{
    self.gradient = [self.gradient gradientByDistributingEvenly];
    [[UIApplication sharedApplication] sendAction:action_ to:target_ from:self forEvent:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    self.gradient = [WDGradient defaultGradient];
    
    return self;
}

- (void)viewDidLoad
{    
    [super viewDidLoad];
    
    self.view.backgroundColor = nil;
    self.view.opaque = NO;
    
    gradientEditor_.controller = self;
}

@end

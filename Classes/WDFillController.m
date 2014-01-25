//
//  WDFillController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDColorController.h"
#import "WDColor.h"
#import "WDColorWell.h"
#import "WDDrawingController.h"
#import "WDGradient.h"
#import "WDGradientController.h"
#import "WDInspectableProperties.h"
#import "WDFillController.h"
#import "WDPropertyManager.h"

@implementation WDFillController

@synthesize drawingController = drawingController_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = NSLocalizedString(@"Fill", @"Fill");
    title.font = [UIFont boldSystemFontOfSize:17.0f];
    title.textColor = [UIColor blackColor];
    title.backgroundColor = nil;
    title.opaque = NO;
    [title sizeToFit];
    
    // make sure the title is centered vertically
    CGRect frame = title.frame;
    frame.size.height = 44;
    title.frame = frame;
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:title];
    self.navigationItem.leftBarButtonItem = item;
    
    modeSegment_ = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"None", @"None"),
                                                              NSLocalizedString(@"Color", @"Color"),
                                                              NSLocalizedString(@"Gradient", @"Gradient")]];
    [modeSegment_ addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    
    item = [[UIBarButtonItem alloc] initWithCustomView:modeSegment_];
    self.navigationItem.rightBarButtonItem = item;
    
    return self;
}

- (void) setDrawingController:(WDDrawingController *)drawingController
{
    drawingController_ = drawingController;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(invalidProperties:)
                                                 name:WDInvalidPropertiesNotification
                                               object:drawingController.propertyManager];
}

- (void) modeChanged:(id)sender
{
    fillMode_ = (int) [modeSegment_ selectedSegmentIndex];
    
    if (fillMode_ == kFillNone) {
        [drawingController_ setValue:[NSNull null] forProperty:WDFillProperty];
    } else if (fillMode_ == kFillColor) {
        [drawingController_ setValue:colorController_.color forProperty:WDFillProperty];
    } else { // gradient
        [drawingController_ setValue:gradientController_.gradient forProperty:WDFillProperty];
    }
}

- (void) takeColorFrom:(id)sender
{
    WDColorController *controller = (WDColorController *)sender;
    
    if (fillMode_ == kFillGradient) {
        [gradientController_ setColor:controller.color];
    } else {
        [drawingController_ setValue:controller.color forProperty:WDFillProperty];
    }
}

- (void) takeGradientFrom:(id)sender
{
    WDGradientController *controller = (WDGradientController *)sender;
    
    [drawingController_ setValue:controller.gradient forProperty:WDFillProperty];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    colorController_ = [[WDColorController alloc] initWithNibName:@"Color" bundle:nil];
    [self.view addSubview:colorController_.view];
    
    CGRect frame = colorController_.view.frame;
    frame.origin = CGPointMake(5, 5);
    colorController_.view.frame = frame;
    
    colorController_.target = self;
    colorController_.action = @selector(takeColorFrom:);
    
    gradientController_ = [[WDGradientController alloc] initWithNibName:@"Gradient" bundle:nil];
    [self.view addSubview:gradientController_.view];
    
    gradientController_.target = self;
    gradientController_.action = @selector(takeGradientFrom:);
    gradientController_.colorController = colorController_;
    
    frame = gradientController_.view.frame;
    frame.origin.x = 5;
    frame.origin.y = CGRectGetMaxY(colorController_.view.frame) + 15;
    gradientController_.view.frame = frame;
    
    frame = self.view.frame;
    frame.size.height = CGRectGetMaxY(gradientController_.view.frame) + 4;
    self.view.frame = frame;
    
    self.preferredContentSize = self.view.frame.size;
}

- (void) configureUIWithFill:(id<WDPathPainter>)fill
{
    if (!fill || [fill isEqual:[NSNull null]]) {
        gradientController_.inactive = YES;
        colorController_.colorWell.gradientStopMode = NO;
        fillMode_ = kFillNone;
    } else if ([fill isKindOfClass:[WDColor class]]) {
        gradientController_.inactive = YES;
        colorController_.colorWell.gradientStopMode = NO;
        colorController_.color = (WDColor *) fill;
        fillMode_ = kFillColor;
    } else {
        gradientController_.inactive = NO;
        colorController_.colorWell.gradientStopMode = YES;
        gradientController_.gradient = (WDGradient *) fill;
        fillMode_ = kFillGradient;
    }
    
    [modeSegment_ removeTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    modeSegment_.selectedSegmentIndex = fillMode_;
    [modeSegment_ addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void) invalidProperties:(NSNotification *)aNotification
{
    NSSet *properties = [aNotification userInfo][WDInvalidPropertiesKey];
    
    if ([properties containsObject:WDFillProperty]) {
        id<WDPathPainter> fill = [drawingController_.propertyManager defaultValueForProperty:WDFillProperty];
        [self configureUIWithFill:fill];
    }
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // set default colors/gradients first
    colorController_.color = [drawingController_.propertyManager defaultValueForProperty:WDFillColorProperty];
    gradientController_.gradient =  [drawingController_.propertyManager defaultValueForProperty:WDFillGradientProperty];
    
    // configure the UI
    id<WDPathPainter> fill = [drawingController_.propertyManager activeFillStyle];
    
    [self configureUIWithFill:fill];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

//
//  WDStrokeController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDArrowController.h"
#import "WDArrowhead.h"
#import "WDColor.h"
#import "WDColorController.h"
#import "WDColorWell.h"
#import "WDDrawingController.h"
#import "WDInspectableProperties.h"
#import "WDLineAttributePicker.h"
#import "WDSparkSlider.h"
#import "WDStrokeController.h"
#import "WDPropertyManager.h"
#import "WDUtilities.h"

@implementation WDStrokeController

@synthesize drawingController = drawingController_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = NSLocalizedString(@"Stroke", @"Stroke");
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
                                                              NSLocalizedString(@"Color", @"Color")]];
   
    // make sure the segment control isn't too squished
    frame = modeSegment_.frame;
    frame.size.width += 40;
    modeSegment_.frame = frame;
    
    [modeSegment_ addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    
    item = [[UIBarButtonItem alloc] initWithCustomView:modeSegment_];
    self.navigationItem.rightBarButtonItem = item;
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

- (void) invalidProperties:(NSNotification *)aNotification
{
    NSSet *properties = [aNotification userInfo][WDInvalidPropertiesKey];
    
    for (NSString *property in properties) {
        id value = [drawingController_.propertyManager defaultValueForProperty:property];
        
        if ([property isEqualToString:WDStrokeWidthProperty]) {
            widthSlider_.value = [self strokeWidthToSliderValue:[value floatValue]];
            widthLabel_.text = [NSString stringWithFormat:@"%.1f pt", [value floatValue]];
            
            decrement.enabled = widthSlider_.value != widthSlider_.minimumValue;
            increment.enabled = widthSlider_.value != widthSlider_.maximumValue;
        } else if ([property isEqualToString:WDStrokeCapProperty]) {
            capPicker_.cap = [value integerValue];
        } else if ([property isEqualToString:WDStrokeJoinProperty]) {
            joinPicker_.join = [value integerValue];
        } else if ([property isEqualToString:WDStrokeColorProperty]) {
            colorController_.color = value;
        } else if ([property isEqualToString:WDStrokeVisibleProperty]) {
            [modeSegment_ removeTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
            modeSegment_.selectedSegmentIndex = [value boolValue] ? 1 : 0;
            [modeSegment_ addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([property isEqualToString:WDStrokeDashPatternProperty]) {
            [self setDashSlidersFromArray:value];
        }
    }
    
    if ([properties intersectsSet:[NSSet setWithObjects:WDStartArrowProperty, WDEndArrowProperty, nil]]) {
        [self updateArrowPreview];
    }
}

#pragma mark - Width Slider

#define kX 40.0f
#define kXLog log(kX + 1)

- (float) widthSliderDelta
{
    return (widthSlider_.maximumValue - widthSlider_.minimumValue);
}

- (float) strokeWidthToSliderValue:(float)strokeWidth
{
    float delta = [self widthSliderDelta];
    float v = (strokeWidth - widthSlider_.minimumValue) * (kX / delta) + 1.0f;
    v = log(v);
    v /= kXLog;
    
    return (v * 100);
}

- (float) sliderValueToStrokeWidth
{
    float percentage = WDClamp(0.0f, 1.0f, (widthSlider_.value) / 100.0f);
    float delta = [self widthSliderDelta];
    float v = delta * (exp(kXLog * percentage) - 1.0f) / kX + widthSlider_.minimumValue;
    
    return v;
}

- (IBAction) takeStrokeWidthFrom:(id)sender
{
    widthLabel_.text = [NSString stringWithFormat:@"%.1f pt", [self sliderValueToStrokeWidth]];
    
    UISlider *slider = (UISlider *)sender;
    decrement.enabled = slider.value != slider.minimumValue;
    increment.enabled = slider.value != slider.maximumValue;
}

- (IBAction) takeFinalStrokeWidthFrom:(id)sender
{
    [drawingController_ setValue:@([self sliderValueToStrokeWidth])
                     forProperty:WDStrokeWidthProperty];
}

- (float) roundingFactor:(float)strokeWidth
{
    if (strokeWidth <= 5.0) {
        return 10.0f;
    } else if (strokeWidth <= 10) {
        return 5.0f;
    } else if (strokeWidth <= 20) {
        return 2.0f;
    }
    
    return 1.0f;
}

- (void) changeSliderBy:(float)change
{
    float strokeWidth = [self sliderValueToStrokeWidth];
    float roundingFactor = [self roundingFactor:strokeWidth];
    
    strokeWidth *= roundingFactor;
    strokeWidth += change;
    strokeWidth = roundf(strokeWidth);
    strokeWidth /= roundingFactor;
    
    widthSlider_.value = [self strokeWidthToSliderValue:strokeWidth];
    [widthSlider_ sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (IBAction) increment:(id)sender
{
    [self changeSliderBy:1];
}

- (IBAction) decrement:(id)sender
{
    [self changeSliderBy:(-1)];
}

#pragma mark - Actions

- (void) modeChanged:(id)sender
{
    mode_ = (int) [modeSegment_ selectedSegmentIndex];
    
    if (mode_ == kStrokeNone) {
        [drawingController_ setValue:@NO forProperty:WDStrokeVisibleProperty];
    } else if (mode_ == kStrokeColor) {
        [drawingController_ setValue:@YES forProperty:WDStrokeVisibleProperty];
    }
}

- (void) takeColorFrom:(id)sender
{
    WDColorController   *colorController = (WDColorController *)sender;
    WDColor             *color = colorController.color;
    
    [drawingController_ setValue:color forProperty:WDStrokeColorProperty];
}

- (IBAction)showArrowheads:(id)sender
{
    WDArrowController *arrowController = [[WDArrowController alloc] initWithNibName:nil bundle:nil];
    arrowController.preferredContentSize = self.view.frame.size;
    arrowController.drawingController = self.drawingController;
	[self.navigationController pushViewController:arrowController animated:YES];
}

- (void) takeCapFrom:(id)sender
{
    WDLineAttributePicker *picker = (WDLineAttributePicker *)sender;
    [drawingController_ setValue:@(picker.cap) forProperty:WDStrokeCapProperty];
}

- (void) takeJoinFrom:(id)sender
{
    WDLineAttributePicker *picker = (WDLineAttributePicker *)sender;
    [drawingController_ setValue:@(picker.join) forProperty:WDStrokeJoinProperty];
}

- (IBAction) toggleDash:(id)sender
{
    NSMutableArray *pattern = [NSMutableArray array];
    
    if (dashSwitch_.isOn) {
        WDStrokeStyle *strokeStyle = [drawingController_.propertyManager activeStrokeStyle];
        
        if (!strokeStyle) {
            strokeStyle = [drawingController_.propertyManager defaultStrokeStyle];
        }
        
        int dash = MIN(100, round(strokeStyle.width * 2));
        [pattern addObject:@((float)dash)];
    }
    
    [drawingController_ setValue:pattern forProperty:WDStrokeDashPatternProperty];
}

- (void) dashChanged:(id)sender
{
    NSMutableArray *pattern = [NSMutableArray array];
    
    [pattern addObject:dash0_.numberValue];
    [pattern addObject:gap0_.numberValue];
    [pattern addObject:dash1_.numberValue];
    [pattern addObject:gap1_.numberValue];
    
    [drawingController_ setValue:pattern forProperty:WDStrokeDashPatternProperty];
}

- (void) setDashSlidersFromArray:(NSArray *)pattern
{
    WDSparkSlider   *sliders[4] = {dash0_, gap0_, dash1_, gap1_};
    int             i;
    
    float sum = 0.0f;
    for (NSNumber *number in pattern) {
        sum += [number floatValue];
    }
    
    dashSwitch_.on = (pattern && pattern.count && sum > 0) ? YES : NO;
    
    if (pattern && pattern.count) {
        for (i = 0; i < pattern.count; i++) {
            sliders[i].value = [pattern[i] floatValue];
        }
        
        for ( ; i < 4; i++) {
            sliders[i].value = 0;
        }
    } else {
        for (i = 0; i < 4; i++) {
            sliders[i].value = 0;
        }
    }
}

#pragma mark - View Life Cycle

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    colorController_ = [[WDColorController alloc] initWithNibName:@"Color" bundle:nil];
    
    [self.view addSubview:colorController_.view];
    CGRect frame = colorController_.view.frame;
    frame.origin = CGPointMake(5, 5);
    colorController_.view.frame = frame;
    colorController_.colorWell.strokeMode = YES;
    
    colorController_.target = self;
    colorController_.action = @selector(takeColorFrom:);
    
    widthSlider_.minimumValue = 0.1f;
    widthSlider_.maximumValue = 100.0f;
    [widthSlider_ addTarget:self action:@selector(takeStrokeWidthFrom:)
          forControlEvents:(UIControlEventTouchDown | UIControlEventTouchDragInside | UIControlEventValueChanged)];
    [widthSlider_ addTarget:self action:@selector(takeFinalStrokeWidthFrom:)
          forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
    
    capPicker_.mode = kStrokeCapAttribute;
    [capPicker_ addTarget:self action:@selector(takeCapFrom:) forControlEvents:UIControlEventValueChanged];
    
    joinPicker_.mode = kStrokeJoinAttribute;
    [joinPicker_ addTarget:self action:@selector(takeJoinFrom:) forControlEvents:UIControlEventValueChanged];
    
    // need to add/remove this target when programmatically changing the segment controller's value
    [modeSegment_ addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    
    dash0_.title.text = NSLocalizedString(@"dash", @"dash");
    dash1_.title.text = NSLocalizedString(@"dash", @"dash");
    gap0_.title.text = NSLocalizedString(@"gap", @"gap");
    gap1_.title.text = NSLocalizedString(@"gap", @"gap");
    
    [dash0_ addTarget:self action:@selector(dashChanged:) forControlEvents:UIControlEventValueChanged];
    [dash1_ addTarget:self action:@selector(dashChanged:) forControlEvents:UIControlEventValueChanged];
    [gap0_ addTarget:self action:@selector(dashChanged:) forControlEvents:UIControlEventValueChanged];
    [gap1_ addTarget:self action:@selector(dashChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.preferredContentSize = self.view.frame.size;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // configure UI elements
    WDStrokeStyle *strokeStyle = [drawingController_.propertyManager defaultStrokeStyle];
    
    colorController_.color = strokeStyle.color;
    widthSlider_.value = [self strokeWidthToSliderValue:strokeStyle.width];
    widthLabel_.text = [NSString stringWithFormat:@"%.1f pt", strokeStyle.width];
    capPicker_.cap = strokeStyle.cap;
    joinPicker_.join = strokeStyle.join;
    
    [self updateArrowPreview];
    [self setDashSlidersFromArray:strokeStyle.dashPattern];
    
    [modeSegment_ removeTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    modeSegment_.selectedSegmentIndex = [[drawingController_.propertyManager defaultValueForProperty:WDStrokeVisibleProperty] boolValue] ? 1 : 0;
    [modeSegment_ addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
}

#pragma mark - Arrow Previews

- (void) updateArrowPreview
{
    [arrowButton_ setImage:[self arrowPreview] forState:UIControlStateNormal];
}

- (UIImage *) arrowPreview
{
    WDStrokeStyle   *strokeStyle = [drawingController_.propertyManager defaultStrokeStyle];
    UIColor         *color = [UIColor colorWithRed:0.0f green:(118.0f / 255) blue:1.0f alpha:1.0f];
    WDArrowhead     *arrow;
    CGContextRef    ctx;
    CGSize          size = arrowButton_.frame.size;
    float           scale = 3.0;
    float           y = floor(size.height / 2) + 0.5f;
    float           arrowInset;
    float           stemStart;
    float           stemEnd = 40;
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    ctx = UIGraphicsGetCurrentContext();
    
    [color set];
    CGContextSetLineWidth(ctx, scale);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    
    // start arrow
    arrow = [WDArrowhead arrowheads][strokeStyle.startArrow];
    arrowInset = arrow.insetLength;
    if (arrow) {
        [arrow addArrowInContext:ctx position:CGPointMake(arrowInset * scale, y)
                           scale:scale angle:M_PI useAdjustment:NO];
        CGContextFillPath(ctx);
        stemStart = arrowInset * scale;
    } else {
        stemStart = 10;
    }
    
    CGContextMoveToPoint(ctx, stemStart, y);
    CGContextAddLineToPoint(ctx, stemEnd, y);
    CGContextStrokePath(ctx);
    
    // end arrow
    arrow = [WDArrowhead arrowheads][strokeStyle.endArrow];
    arrowInset = arrow.insetLength;
    if (arrow) {
        [arrow addArrowInContext:ctx position:CGPointMake(size.width - (arrowInset * scale), y)
                           scale:scale angle:0 useAdjustment:NO];
        CGContextFillPath(ctx);
        stemStart = arrowInset * scale;
    } else {
        stemStart = 10;
    }
    
    CGContextMoveToPoint(ctx, size.width - stemStart, y);
    CGContextAddLineToPoint(ctx, size.width - stemEnd, y);
    CGContextStrokePath(ctx);
    
    // draw interior line
    [[color colorWithAlphaComponent:0.5f] set];
    CGContextMoveToPoint(ctx, stemEnd + 10, y);
    CGContextAddLineToPoint(ctx, size.width - (stemEnd + 10), y);
    CGContextSetLineWidth(ctx, scale - 2);
    CGContextStrokePath(ctx);
    
    // draw a label
    NSString *label = NSLocalizedString(@"arrowheads", @"arrowheads");
    NSDictionary *attrs = @{NSFontAttributeName: [UIFont systemFontOfSize:15.0f],
                            NSForegroundColorAttributeName:color};
    CGRect bounds = CGRectZero;
    bounds.size = [label sizeWithAttributes:attrs];
    bounds.origin.x = (size.width - CGRectGetWidth(bounds)) / 2;
    bounds.origin.y = (size.height - CGRectGetHeight(bounds)) / 2 - 1;
    CGContextSetBlendMode(ctx, kCGBlendModeClear);
    CGContextFillRect(ctx, CGRectInset(bounds, -10, -10));
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    [label drawInRect:bounds withAttributes:attrs];
    
    // grab the image
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

@end

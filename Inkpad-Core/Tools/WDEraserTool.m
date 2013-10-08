//
//  WDEraserTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDBezierNode.h"
#import "WDCanvas.h"
#import "WDColor.h"
#import "WDCurveFit.h"
#import "WDDrawing.h"
#import "WDDrawingController.h"
#import "WDEraserTool.h"
#import "WDPath.h"
#import "WDUtilities.h"

NSString *WDEraserToolSize = @"WDEraserToolSize";

#define kOptionsViewCornerRadius    9
#define kMaxError                   5.0f

@implementation WDEraserTool

- (NSString *) iconName
{
    return @"eraser.png";
}

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    eraserSize_ = [defaults floatForKey:WDEraserToolSize];
    if (eraserSize_ == 0.0f) {
        eraserSize_ = 20.0f;
    }

    return self;
}

- (void) beginWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    tempPath_ = [[WDPath alloc] initWithNode:[WDBezierNode bezierNodeWithAnchorPoint:theEvent.location]];
    
    tempPath_.strokeStyle = [WDStrokeStyle strokeStyleWithWidth:eraserSize_ cap:kCGLineCapRound
                                                           join:kCGLineJoinRound
                                                          color:[WDColor colorWithWhite:0.9f alpha:0.85f]
                                                    dashPattern:nil];
    canvas.eraserPath = tempPath_;
}

- (void) moveWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    if (WDDistance(theEvent.location, [tempPath_ lastNode].anchorPoint) < (3.0f / canvas.viewScale)) {
        return;
    }
    
    [tempPath_.nodes addObject:[WDBezierNode bezierNodeWithAnchorPoint:theEvent.location]];
    [tempPath_ invalidatePath];
    canvas.eraserPath = tempPath_;
    
    [canvas invalidateSelectionView];
}

- (void) endWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    canvas.eraserPath = nil;
    
    if (tempPath_ && [tempPath_.nodes count] > 1) {
        NSMutableArray *points = [NSMutableArray array];
        for (WDBezierNode *node in tempPath_.nodes) {
            [points addObject:[NSValue valueWithCGPoint:node.anchorPoint]];
        }
        
        WDPath *smoothPath = [WDCurveFit smoothPathForPoints:points error:(kMaxError / canvas.viewScale) attemptToClose:NO];
        
        if (smoothPath) {
            smoothPath.strokeStyle = [WDStrokeStyle strokeStyleWithWidth:eraserSize_
                                                                     cap:kCGLineCapRound
                                                                    join:kCGLineJoinRound
                                                                   color:[WDColor blackColor]
                                                             dashPattern:nil];
            WDAbstractPath *erasePath = [smoothPath outlineStroke];
            
            [canvas.drawingController eraseWithPath:erasePath];
        }
    }
    
    tempPath_ = nil;
}

#if TARGET_OS_IPHONE

- (void) updateOptionsSettings
{
    optionsValue_.text = [NSString stringWithFormat:@"%d", eraserSize_];
    optionsSlider_.value = eraserSize_;
}

- (void) takeFinalSliderValueFrom:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    eraserSize_ = optionsSlider_.value;
    [defaults setInteger:eraserSize_ forKey:WDEraserToolSize];

    [self updateOptionsSettings];
}

- (void) takeSliderValueFrom:(id)sender
{
    eraserSize_ = optionsSlider_.value;
    [self updateOptionsSettings];
}

- (IBAction)increment:(id)sender
{
    optionsSlider_.value = optionsSlider_.value + 1;
    [optionsSlider_ sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (IBAction)decrement:(id)sender
{
    optionsSlider_.value = optionsSlider_.value - 1;
    [optionsSlider_ sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (UIView *) optionsView
{
    if (!optionsView_) {
        [[NSBundle mainBundle] loadNibNamed:@"ShapeOptions" owner:self options:nil];
        
        optionsSlider_.minimumValue = 1;
        optionsSlider_.maximumValue = 100;
        optionsSlider_.backgroundColor = nil;
        optionsSlider_.exclusiveTouch = YES;
        
        optionsView_.layer.cornerRadius = kOptionsViewCornerRadius;
        
        UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:optionsView_.bounds cornerRadius:kOptionsViewCornerRadius];
        CALayer *layer = optionsView_.layer;
        
        layer.shadowPath = shadowPath.CGPath;
        layer.shadowOpacity = 0.33f;
        layer.shadowRadius = 10;
        layer.shadowOffset = CGSizeZero;
        
        optionsTitle_.text = NSLocalizedString(@"Eraser Size", @"Eraser Size");
        
        [optionsSlider_ addTarget:self
                           action:@selector(takeSliderValueFrom:)
                 forControlEvents:UIControlEventValueChanged];
        
        [optionsSlider_ addTarget:self
                           action:@selector(takeFinalSliderValueFrom:)
                 forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
    }
    
    [self updateOptionsSettings];
    
    return optionsView_;
}

#endif

@end

//
//  WDToolButton.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDCanvas.h"
#import "WDPalette.h"
#import "WDTool.h"
#import "WDToolButton.h"
#import "WDToolManager.h"
#import "WDToolView.h"

@implementation WDToolButton

@synthesize tool = tool_;
@synthesize tools = tools_;

+ (float) dimension
{
    return 42;
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activeToolChanged:) name:WDActiveToolDidChange object:nil];
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) dismissSubtoolsAnimated:(BOOL)animated
{
    if (subtoolsPopover_) {
        [subtoolsPopover_ dismissPopoverAnimated:animated];
        subtoolsPopover_ = nil;
    }
}

- (void) canvasStartedTracking:(NSNotification *)aNotification
{
    [self dismissSubtoolsAnimated:NO];
}

- (void) paletteMoved:(NSNotification *)aNotification
{
    [self dismissSubtoolsAnimated:NO];
}

- (void) activeToolChanged:(NSNotification *)aNotification
{
    if (tools_) {
        WDTool *tool = [[WDToolManager sharedInstance] activeTool];
        
        if (![tools_ containsObject:tool]) {
            [self dismissSubtoolsAnimated:NO];
            self.selected = NO;
            return;
        }
        
        self.tool = tool;
    }
    
    self.selected = ([WDToolManager sharedInstance].activeTool == self.tool) ? YES : NO;
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (subtoolsPopover_) {
        [self dismissSubtoolsAnimated:NO];
    }
    
    return [super beginTrackingWithTouch:touch withEvent:event];
}

- (UIColor *) toolTintColor
{
    return [UIColor colorWithRed:(66.0f / 255) green:(102.0f / 255) blue:(151.0f / 255) alpha:1.0f];
}

- (UIColor *) toolSelectedBackgroundColor
{
    return [UIColor colorWithRed:0.0f green:(118.0f / 255) blue:1.0f alpha:1.0f];
}

- (void) drawDisclosueInContext:(CGContextRef)ctx
{
    float midX = 4, midY = 11;
    
    CGContextMoveToPoint(ctx, [WDToolButton dimension] - (midX + 3), [WDToolButton dimension] - (midY + 3));
    CGContextAddLineToPoint(ctx, [WDToolButton dimension] - midX, [WDToolButton dimension] - midY);
    CGContextAddLineToPoint(ctx, [WDToolButton dimension] - (midX + 3), [WDToolButton dimension] - (midY - 3));
    CGContextSetLineCap(ctx, kCGLineCapButt);
    CGContextSetLineWidth(ctx, 2.0f);
    CGContextStrokePath(ctx);
}

- (UIImage *) backgroundImageWithRenderBlock:(void (^)(CGContextRef ctx))renderBlock
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake([WDToolButton dimension], [WDToolButton dimension]), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    renderBlock(ctx);
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

- (UIImage *) disclosureBackground
{
    UIImage *disclosure = [self backgroundImageWithRenderBlock:^(CGContextRef ctx) {
        [[self toolTintColor] set];
        [self drawDisclosueInContext:ctx];
    }];
    
    return [disclosure imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *) selectedBackgroundWithDisclosure:(BOOL)drawDisclosure
{
    CGRect buttonRect = CGRectMake(0, 0, [WDToolButton dimension], [WDToolButton dimension]);
    
    return [self backgroundImageWithRenderBlock:^(CGContextRef ctx) {
        [[self toolSelectedBackgroundColor] set];
        CGContextFillRect(ctx, buttonRect);
        
        if (drawDisclosure) {
            [[UIColor whiteColor] set];
            [self drawDisclosueInContext:ctx];
        }
    }];
}

- (void) setTool:(WDTool *)tool
{
    tool_ = tool;
    
    UIImage *tinted = [tool.icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self setImage:tinted forState:UIControlStateNormal];
    self.tintColor = [self toolTintColor];
    [self setImage:tool.icon forState:UIControlStateSelected];
    
    if (!tools_) {
        [self setBackgroundImage:[self selectedBackgroundWithDisclosure:NO] forState:UIControlStateSelected];
    }
}

- (void) popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (popoverController == subtoolsPopover_) {
        subtoolsPopover_ = nil;
    }
}

- (void) didChooseTool:(WDToolView *)toolView
{
    [self dismissSubtoolsAnimated:YES];
}

- (void) showTools:(id)sender
{
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
    
    if (!subtoolsPopover_) {
        WDToolView *subtools = [[WDToolView alloc] initWithTools:tools_];
        subtools.owner = self;
        
        UIViewController *vc = [[UIViewController alloc] initWithNibName:nil bundle:nil];
        vc.preferredContentSize = subtools.frame.size;
        vc.view = subtools;
        
        subtoolsPopover_ = [[UIPopoverController alloc] initWithContentViewController:vc];
        subtoolsPopover_.delegate = self;
        
        WDToolView *parent = (WDToolView *)self.superview;
        subtoolsPopover_.passthroughViews = @[self.superview, parent.canvas];
        
        [subtoolsPopover_ presentPopoverFromRect:self.bounds inView:self permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
    }
}

- (void) setTools:(NSArray *)tools
{
    tools_ = tools;
    
    for (WDTool *tool in tools) {
        if ([tool isDefaultForKind]) {
            self.tool = tool;
            break;
        }
    }
    
    [self setBackgroundImage:[self disclosureBackground] forState:UIControlStateNormal];
    [self setBackgroundImage:[self selectedBackgroundWithDisclosure:YES] forState:UIControlStateSelected];
    
    
    UILongPressGestureRecognizer *longTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showTools:)];
    longTap.minimumPressDuration = 0.25f;
    [self addGestureRecognizer:longTap];
    
    // if the palette moves we need to hide our popover
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(paletteMoved:)
                                                 name:WDPaletteMovedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(canvasStartedTracking:)
                                                 name:WDCanvasBeganTrackingTouches
                                               object:nil];
}

@end

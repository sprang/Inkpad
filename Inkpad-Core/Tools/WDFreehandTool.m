//
//  WDFreehandTool.m
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
#import "WDDrawingController.h"
#import "WDFreehandTool.h"
#import "WDInspectableProperties.h"
#import "WDPath.h"
#import "WDPropertyManager.h"
#import "WDUtilities.h"

#define kMaxError 10.0f

NSString *WDDefaultFreehandTool = @"WDDefaultFreehandTool";

@implementation WDFreehandTool

@synthesize closeShape = closeShape_;

- (NSString *) iconName
{
    return closeShape_ ? @"freehand_shape.png" : @"brush.png";
}

- (BOOL) createsObject
{
    return YES;
}

- (BOOL) isDefaultForKind
{
    NSNumber *defaultFreehand = [[NSUserDefaults standardUserDefaults] valueForKey:WDDefaultFreehandTool];
    return (closeShape_ == [defaultFreehand intValue]) ? YES : NO;
}

- (void) activated
{
    [[NSUserDefaults standardUserDefaults] setValue:@(closeShape_) forKey:WDDefaultFreehandTool];
}

- (void) beginWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    [canvas.drawingController selectNone:nil];
    
    pathStarted_ = YES;
    
    tempPath_ = [[WDPath alloc] init];
    canvas.shapeUnderConstruction = tempPath_;
    
    [self moveWithEvent:theEvent inCanvas:canvas];
}

- (void) moveWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    [tempPath_.nodes addObject:[WDBezierNode bezierNodeWithAnchorPoint:theEvent.location]];
    [canvas invalidateSelectionView];
}

- (void) endWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    if (pathStarted_ && [tempPath_.nodes count] > 1) {
        float maxError = (kMaxError / canvas.viewScale);
        
        canvas.shapeUnderConstruction = nil;
        
        NSMutableArray *points = [NSMutableArray array];
        for (WDBezierNode *node in tempPath_.nodes) {
            [points addObject:[NSValue valueWithCGPoint:node.anchorPoint]];
        }
        
        if (closeShape_ && tempPath_.nodes.count > 2) {
            // we're drawing free form closed shapes... let's relax the error
            maxError *= 5;
            
            // add the first point at the end to make sure we close
            CGPoint first = [points[0] CGPointValue];
            CGPoint last = [[points lastObject] CGPointValue];
                
            if (WDDistance(first, last) >= (maxError*2)) {
                [points addObject:points[0]];
            }
        }
        
        WDPath *smoothPath = [WDCurveFit smoothPathForPoints:points error:maxError attemptToClose:YES];
        
        if (smoothPath) {
            smoothPath.fill = [canvas.drawingController.propertyManager activeFillStyle];
            smoothPath.strokeStyle = [canvas.drawingController.propertyManager activeStrokeStyle];
            smoothPath.opacity = [[canvas.drawingController.propertyManager defaultValueForProperty:WDOpacityProperty] floatValue];
            smoothPath.shadow = [canvas.drawingController.propertyManager activeShadow];
            
            [canvas.drawing addObject:smoothPath];
            [canvas.drawingController selectObject:smoothPath];
        }
    }
    
    pathStarted_ = NO;
    tempPath_ = nil;
}

@end

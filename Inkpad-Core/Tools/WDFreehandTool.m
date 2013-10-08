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
#import "WDDrawing.h"
#import "WDDrawingController.h"
#import "WDFreehandTool.h"
#import "WDInspectableProperties.h"
#import "WDPath.h"
#import "WDPropertyManager.h"

#define kMaxError 10.0f

@implementation WDFreehandTool

- (NSString *) iconName
{
    return @"brush.png";
}

- (BOOL) createsObject
{
    return YES;
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
        canvas.shapeUnderConstruction = nil;
        
        NSMutableArray *points = [NSMutableArray array];
        for (WDBezierNode *node in tempPath_.nodes) {
            [points addObject:[NSValue valueWithCGPoint:node.anchorPoint]];
        }
        
        WDPath *smoothPath = [WDCurveFit smoothPathForPoints:points error:(kMaxError / canvas.viewScale) attemptToClose:YES];
        
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

//
//  WDToolManager.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDAddAnchorTool.h"
#import "WDEyedropperTool.h"
#import "WDEraserTool.h"
#import "WDFreehandTool.h"
#import "WDPenTool.h"
#import "WDRotateTool.h"
#import "WDScaleTool.h"
#import "WDScissorTool.h"
#import "WDSelectionTool.h"
#import "WDShapeTool.h"
#import "WDTextTool.h"
#import "WDToolManager.h"

NSString *WDActiveToolDidChange = @"WDActiveToolDidChange";

@implementation WDToolManager

@synthesize activeTool = activeTool_;
@synthesize tools = tools_;

+ (WDToolManager *) sharedInstance
{
    static WDToolManager *toolManager_ = nil;
    
    if (!toolManager_) {
        toolManager_ = [[WDToolManager alloc] init];
        toolManager_.activeTool = (toolManager_.tools)[0];
    }
    
    return toolManager_;
}

- (NSArray *) tools
{
    if (!tools_) {
        WDSelectionTool *groupSelect = (WDSelectionTool *) [WDSelectionTool tool];
        groupSelect.groupSelect = YES;
        
        WDShapeTool *oval = (WDShapeTool *) [WDShapeTool tool];
        oval.shapeMode = WDShapeOval;
        
        WDShapeTool *rect = (WDShapeTool *) [WDShapeTool tool];
        rect.shapeMode = WDShapeRectangle;
        
        WDShapeTool *star = (WDShapeTool *) [WDShapeTool tool];
        star.shapeMode = WDShapeStar;
        
        WDShapeTool *poly = (WDShapeTool *) [WDShapeTool tool];
        poly.shapeMode = WDShapePolygon;
        
        WDShapeTool *line = (WDShapeTool *) [WDShapeTool tool];
        line.shapeMode = WDShapeLine;
        
        WDShapeTool *spiral = (WDShapeTool *) [WDShapeTool tool];
        spiral.shapeMode = WDShapeSpiral;
        
        tools_ = @[[WDSelectionTool tool],
                  groupSelect,
                  [WDPenTool tool],
                  [WDAddAnchorTool tool],
                  [WDScissorTool tool],
                  [WDFreehandTool tool],
                  [WDEraserTool tool],
                  @[rect, oval, star, poly, spiral, line],
                  [WDTextTool tool],
                  [WDEyedropperTool tool], 
                  [WDScaleTool tool],
                  [WDRotateTool tool]];
    }
    
    return tools_;
}

- (void) setActiveTool:(WDTool *)activeTool
{
    [activeTool_ deactivated];
    activeTool_ = activeTool;
    [activeTool_ activated];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WDActiveToolDidChange object:nil userInfo:nil];
}

@end

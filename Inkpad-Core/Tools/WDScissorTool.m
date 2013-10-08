//
//  WDScissorTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//
#import "WDScissorTool.h"
#import "WDBezierNode.h"
#import "WDCanvas.h"
#import "WDDrawingController.h"
#import "WDPath.h"

@implementation WDScissorTool

- (NSString *) iconName
{
    return @"scissor.png";
}

- (void) beginWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    WDPickResult *result = [canvas.drawingController snappedPoint:theEvent.location
                                                        viewScale:canvas.viewScale
                                                        snapFlags:(kWDSnapEdges | kWDSnapNodes)];
    WDPath *path = (WDPath *) result.element;
    
    if (![path isKindOfClass:[WDPath class]]) {
        return;
    }
    
    if (result.snapped) {
        NSDictionary *whatToSelect = nil;
        
        if (result.type != kWDEdge && result.nodePosition != kWDMiddleNode) {
            // don't want to split at the first or last node!
            return;
        }
        
        if (result.type == kWDEdge) {
            whatToSelect = [path splitAtPoint:result.snappedPoint viewScale:canvas.viewScale];
        } else if (result.type == kWDAnchorPoint) {
            whatToSelect = [path splitAtNode:result.node];
        }
        
        [canvas.drawingController selectNone:nil];
        [canvas.drawingController selectObject:whatToSelect[@"path"]];
        [canvas.drawingController selectNode:whatToSelect[@"node"]];
    }
}

@end

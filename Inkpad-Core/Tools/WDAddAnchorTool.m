//
//  WDAddAnchorTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDAddAnchorTool.h"
#import "WDBezierNode.h"
#import "WDCanvas.h"
#import "WDDrawingController.h"
#import "WDPath.h"

@implementation WDAddAnchorTool

- (NSString *) iconName
{
    return @"add_anchor.png";
}

- (void) beginWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{
    WDPickResult *result = [canvas.drawingController snappedPoint:event.location
                                                        viewScale:canvas.viewScale
                                                        snapFlags:(kWDSnapEdges | kWDSnapNodes)];
    WDPath *path = (WDPath *) result.element;
    
    if (![path isKindOfClass:[WDPath class]]) {
        return;
    }
    
    WDDrawingController *dc = canvas.drawingController;
    
    if (result.snapped && result.type == kWDEdge) {
        [dc selectNone:nil];
        [dc selectObject:result.element];
        
        WDBezierNode *newestNode = [path addAnchorAtPoint:result.snappedPoint viewScale:canvas.viewScale];
        [dc selectNode:newestNode];
    }
    
    if (result.snapped && result.type == kWDAnchorPoint && [dc isSelected:path]) {
        [dc deselectAllNodes];
        [dc selectNode:result.node];
        
        [path deleteAnchor:result.node];
    }
}

@end

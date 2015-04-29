//
//  WDTextTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//


#import "WDCanvas.h"
#import "WDCanvasController.h"
#import "WDColor.h"
#import "WDDrawingController.h"
#import "WDPath.h"
#import "WDText.h"
#import "WDTextTool.h"
#import "WDUtilities.h"

@implementation WDTextTool

- (NSString *) iconName
{
    return @"text.png";
}

- (BOOL) createsObject
{
    return YES;
}

- (void) moveWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{
    if (!self.moved) {
        [canvas.drawingController selectNone:nil];
    }
    
    WDPath  *temp = [WDPath pathWithRect:WDRectWithPoints(self.initialEvent.snappedLocation, event.snappedLocation)];
    canvas.shapeUnderConstruction = temp;
}

- (void) endWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{
    WDText  *textObj = nil;
    
    // clear path under construction
    canvas.shapeUnderConstruction = nil;
    
    if (self.moved) {
        CGRect placedRect = WDRectWithPoints(self.initialEvent.snappedLocation, event.snappedLocation);
        placedRect.size.width = MAX([WDText minimumWidth], placedRect.size.width);
        
        textObj = [canvas.drawingController createTextObjectInRect:placedRect];
        [canvas.controller editTextObject:textObj selectAll:YES];
    } else { // see if we tapped an existing text object
        WDPickResult    *result = [canvas.drawingController objectUnderPoint:event.location viewScale:canvas.viewScale];
        textObj = (WDText *) result.element;
        
        if (textObj && [textObj hasEditableText]) {
            [canvas.drawingController selectNone:nil];
            [canvas.drawingController selectObject:textObj];
            [canvas.controller editTextObject:textObj selectAll:NO];
        }
    }
}

@end

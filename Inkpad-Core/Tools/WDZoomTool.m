//
//  WDZoomTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import "WDZoomTool.h"
#import "WDCanvas.h"
#import "WDUtilities.h"

#if TARGET_OS_MAC
#import "WDDocument.h"
#endif

@implementation WDZoomTool

- (NSString *) iconName
{
    return @"zoom.png";
}

- (void) moveWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{   
    canvas.marquee = [NSValue valueWithCGRect:WDRectWithPoints(self.initialEvent.location, event.location)];
}

#if !TARGET_OS_IPHONE
- (void) endWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{    
    CGPoint pt = event.location;
    
    if (!self.moved) {
        (self.flags & WDToolOptionKey) ? [canvas zoomOutAtPoint:pt] : [canvas zoomInAtPoint:pt];
    } else {
        [canvas zoomInToRect:WDRectWithPoints(self.initialEvent.location, pt)];
        canvas.marquee = nil;
    }
}
#endif

- (void) buttonDoubleTapped
{
#if !TARGET_OS_IPHONE
    WDDocument *doc = [[NSDocumentController sharedDocumentController] currentDocument];
    
    if (doc) {
        [doc.canvas makeActualSize:nil];
    }
#endif
}

@end

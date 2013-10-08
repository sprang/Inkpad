//
//  WDHandTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDHandTool.h"

#if TARGET_OS_MAC
#import "WDDocument.h"
#endif

@implementation WDHandTool

@synthesize lastWindowLocation = lastWindowLocation_;

- (NSString *) iconName
{
    return @"hand.png";
}

#if !TARGET_OS_IPHONE

- (void) mouseDown:(NSEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    [canvas beginGestureMode];
    lastWindowLocation_ = [theEvent locationInWindow];
}

- (void) mouseDragged:(NSEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    CGPoint delta = WDSubtractPoints([canvas convertPointFromBase:[theEvent locationInWindow]],
                                     [canvas convertPointFromBase:lastWindowLocation_]);
    lastWindowLocation_ = [theEvent locationInWindow];
    
    CGRect visibleRect = canvas.visibleRect;
    CGPoint newOrigin = WDSubtractPoints(visibleRect.origin, delta);
    [canvas scrollPoint:newOrigin];
}

- (void) mouseUp:(NSEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    [canvas endGestureMode];
}

#endif

- (void) buttonDoubleTapped
{
#if !TARGET_OS_IPHONE
    WDDocument *doc = [[NSDocumentController sharedDocumentController] currentDocument];
    
    if (doc) {
        [doc.canvas fitInWindow:nil];
    }
#endif
}

@end

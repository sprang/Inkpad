//
//  WDEyedropperTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDEyedropperTool.h"
#import "WDCanvas.h"
#import "WDDrawingController.h"
#import "WDElement.h"
#import "WDImage.h"
#import "WDInspectableProperties.h"
#import "WDPickResult.h"

#if TARGET_OS_IPHONE
#import "WDEyedropper.h"
#endif

@implementation WDEyedropperTool

@synthesize lastPickResult = lastPickResult_;
@synthesize lastFill = lastFill_;

- (NSString *) iconName
{
    return @"eyedropper.png";
}

- (void) beginWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
#if TARGET_OS_IPHONE
    CGPoint pt = theEvent.location;
    
    [canvas displayEyedropperAtPoint:pt];
    
    self.lastPickResult = [canvas.drawingController inspectableUnderPoint:pt viewScale:canvas.viewScale];
    canvas.eyedropper.fill = self.lastFill = [self.lastPickResult.element pathPainterAtPoint:pt];
#endif
}

- (void) moveWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{   
#if TARGET_OS_IPHONE
    CGPoint pt = theEvent.location;
    
    self.lastPickResult = [canvas.drawingController inspectableUnderPoint:pt viewScale:canvas.viewScale];
    canvas.eyedropper.fill = self.lastFill = [self.lastPickResult.element pathPainterAtPoint:pt];
    
    [canvas moveEyedropperToPoint:pt];
#endif
}

- (void) endWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{    
#if TARGET_OS_IPHONE
    WDElement *element = self.lastPickResult.element;
    if (element) {
        for (NSString *property in [element inspectableProperties]) {
            [canvas.drawingController setValue:[element valueForProperty:property] forProperty:property];
        }
    }
    
    if ([element isKindOfClass:[WDImage class]]) {
        [canvas.drawingController setValue:lastFill_ forProperty:WDFillProperty];
    }
    
    self.lastPickResult = nil;
    self.lastFill = nil;
    
    [canvas dismissEyedropper];
#endif
}

@end

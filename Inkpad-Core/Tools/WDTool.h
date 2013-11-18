//
//  WDTool.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class WDCanvas;
@class WDDrawing;

typedef enum {
    WDToolDefault           = 0,
    WDToolShiftKey          = 1 << 0,
    WDToolOptionKey         = 1 << 1,
    WDToolControlKey        = 1 << 2,
    WDToolSecondaryTouch    = 1 << 3
} WDToolFlags;

// Generic event object to abstract touches and clicks
@interface WDEvent : NSObject
@property (nonatomic, assign) CGPoint location; // coordinate in document space
@property (nonatomic, assign) CGPoint snappedLocation; // snapped coordinate in document space
@property (nonatomic, assign) NSUInteger count; // tap or click count
@end

@interface WDTool : NSObject

@property (weak, nonatomic, readonly) id icon;
@property (weak, nonatomic, readonly) NSString *iconName;
@property (nonatomic, readonly) BOOL needsPivot;
@property (nonatomic, readonly) BOOL primaryTouchEnded;
@property (weak, nonatomic, readonly) UITouch *primaryTouch;
@property (nonatomic, readonly) BOOL moved;
@property (nonatomic, readonly) BOOL createsObject;
@property (weak, nonatomic, readonly) UIView *optionsView;

@property (nonatomic, strong) WDEvent *initialEvent;
@property (nonatomic, strong) WDEvent *previousEvent;
@property (nonatomic, readonly) WDToolFlags flags;

+ (WDTool *) tool;
- (void) activated;
- (void) deactivated;
- (BOOL) isDefaultForKind;

// apply common options view settings (shadow, etc.)
- (void) configureOptionsView:(UIView *)options;

#if TARGET_OS_IPHONE
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event inCanvas:(WDCanvas *)canvas;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event inCanvas:(WDCanvas *)canvas;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event inCanvas:(WDCanvas *)canvas;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event inCanvas:(WDCanvas *)canvas;
#else
- (void) mouseDown:(NSEvent *)theEvent inCanvas:(WDCanvas *)canvas;
- (void) mouseDragged:(NSEvent *)theEvent inCanvas:(WDCanvas *)canvas;
- (void) mouseUp:(NSEvent *)theEvent inCanvas:(WDCanvas *)canvas;
- (void) flagsChanged:(NSEvent *)theEvent inCanvas:(WDCanvas *)canvas;
#endif

// generic event handling code

- (void) beginWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas;
- (void) moveWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas;
- (void) endWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas;

- (void) setFlags:(WDToolFlags)flags inCanvas:(WDCanvas *)canvas;
- (void) flagsChangedInCanvas:(WDCanvas *)canvas;

- (void) buttonDoubleTapped;

// raw drawing coordinate -> snapped drawing coordinate
- (CGPoint) snappedPointForPoint:(CGPoint)pt inCanvas:(WDCanvas *)canvas;

@end

//
//  WDSVGStyleParser.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Original implementation by Scott Vachalek
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>
#import "WDStylable.h"
#import "WDSVGParserStateStack.h"

// SVG properties. All properties should be accessed via one of these constants, and each of these constants should have a defined default value.

extern NSString * const kWDPropertyClipRule;
extern NSString * const kWDPropertyColor;
extern NSString * const kWDPropertyDisplay;
extern NSString * const kWDPropertyFill;
extern NSString * const kWDPropertyFillOpacity;
extern NSString * const kWDPropertyFontFamily;
extern NSString * const kWDPropertyFontSize;
extern NSString * const kWDPropertyOpacity;
extern NSString * const kWDPropertyStopColor;
extern NSString * const kWDPropertyStopOpacity;
extern NSString * const kWDPropertyStroke;
extern NSString * const kWDPropertyStrokeDashArray;
extern NSString * const kWDPropertyStrokeDashOffset;
extern NSString * const kWDPropertyStrokeLineCap;
extern NSString * const kWDPropertyStrokeLineJoin;
extern NSString * const kWDPropertyStrokeOpacity;
extern NSString * const kWDPropertyStrokeWidth;
extern NSString * const kWDPropertyTextAnchor;
extern NSString * const kWDPropertyVisibility;


@interface WDSVGStyleParser : NSObject {
    WDSVGParserStateStack   *stack_;
    NSMutableDictionary     *painters_;
    NSMutableDictionary     *blendModeNames_;
    NSMutableDictionary     *forwardReferences_;
}

- (id) initWithStack:(WDSVGParserStateStack *)stack;
- (id) resolvePainter:(NSString *)source alpha:(float)alpha;
- (NSDictionary *) parseStyles:(NSString *)source;
- (void) styleOpacityBlendAndShadow:(WDElement *)element;
- (void) style:(WDStylable *)stylable;
- (NSDictionary *) defaultStyle;

- (void) setPainter:(id<WDPathPainter>)painter withTransform:(WDFillTransform *)transform forId:(NSString *)painterId;
- (id<WDPathPainter>) painterForId:(NSString *)painterId;
- (WDFillTransform *) transformForId:(NSString *)painterId;
    
- (void) registerGradient:(NSString *)gradient forForwardReference:(NSString *)forwardReference;
    
@end
